"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupUserOnDelete = void 0;
const admin = __importStar(require("firebase-admin"));
const auth_1 = require("firebase-functions/v1/auth");
const deleteQueryDocs = async (snapshot, writer) => {
    snapshot.docs.forEach((doc) => writer.delete(doc.ref));
};
const deleteCollection = async (query, writer) => {
    const snapshot = await query.get();
    if (snapshot.empty)
        return;
    await deleteQueryDocs(snapshot, writer);
};
const deleteStoragePrefix = async (prefix) => {
    const bucket = admin.storage().bucket();
    try {
        await bucket.deleteFiles({ prefix });
    }
    catch (error) {
        console.warn(`storage cleanup failed for ${prefix}`, error);
    }
};
exports.cleanupUserOnDelete = (0, auth_1.user)().onDelete(async (user) => {
    const uid = user.uid;
    const db = admin.firestore();
    const writer = db.bulkWriter();
    const userRef = db.collection("users").doc(uid);
    await deleteCollection(userRef.collection("subscriptions"), writer);
    await deleteCollection(userRef.collection("billingHistory"), writer);
    await deleteCollection(userRef.collection("notifications"), writer);
    writer.delete(userRef);
    const invitesSnapshot = await db.collection("groupInvites")
        .where("createdBy", "==", uid)
        .get();
    await deleteQueryDocs(invitesSnapshot, writer);
    const groupsSnapshot = await db.collection("groups")
        .where("memberIds", "array-contains", uid)
        .get();
    for (const groupDoc of groupsSnapshot.docs) {
        const data = groupDoc.data();
        const groupRef = groupDoc.ref;
        const ownerId = data.ownerId;
        const memberIds = Array.isArray(data.memberIds) ? data.memberIds : [];
        const remainingIds = memberIds.filter((id) => id !== uid);
        const preview = Array.isArray(data.membersPreview)
            ? data.membersPreview
            : Array.isArray(data.members)
                ? data.members
                : [];
        const updatedPreview = preview.filter((member) => member.userId !== uid);
        if (ownerId === uid) {
            if (remainingIds.length === 0) {
                const membersSnapshot = await groupRef.collection("members").get();
                await deleteQueryDocs(membersSnapshot, writer);
                writer.delete(groupRef);
            }
            else {
                const newOwnerId = remainingIds[0];
                writer.update(groupRef, {
                    ownerId: newOwnerId,
                    memberIds: remainingIds,
                    membersPreview: updatedPreview,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                const newOwnerSnapshot = await groupRef.collection("members")
                    .where("userId", "==", newOwnerId)
                    .get();
                newOwnerSnapshot.docs.forEach((doc) => {
                    writer.update(doc.ref, {
                        role: "owner",
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                });
            }
        }
        else {
            writer.update(groupRef, {
                memberIds: remainingIds,
                membersPreview: updatedPreview,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
        const userMemberSnapshot = await groupRef.collection("members")
            .where("userId", "==", uid)
            .get();
        await deleteQueryDocs(userMemberSnapshot, writer);
    }
    await writer.close();
    await deleteStoragePrefix(`users/${uid}/`);
    for (const groupDoc of groupsSnapshot.docs) {
        await deleteStoragePrefix(`groups/${groupDoc.id}/receipts/${uid}/`);
    }
});
