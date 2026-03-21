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
exports.notifyOwnerOnPaymentSubmittedTest = exports.notifyOwnerOnMemberLeft = exports.notifyOwnerOnMemberJoined = exports.notifyMemberOnPaymentStatusChanged = exports.notifyOwnerOnPaymentSubmitted = exports.markOverdueTest = exports.sendBillingRemindersTest = exports.sendBillingReminders = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const INVALID_TOKEN_CODES = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
    "messaging/invalid-argument"
]);
const chunk = (items, size) => {
    const result = [];
    for (let index = 0; index < items.length; index += size) {
        result.push(items.slice(index, index + size));
    }
    return result;
};
const cleanupInvalidTokens = async (db, tokenChunk, responses, tokenUserMap) => {
    if (!tokenUserMap) {
        return;
    }
    const removals = new Map();
    responses.responses.forEach((item, index) => {
        if (item.success) {
            return;
        }
        const code = item.error?.code ?? "";
        if (!INVALID_TOKEN_CODES.has(code)) {
            return;
        }
        const token = tokenChunk[index];
        const userId = tokenUserMap.get(token);
        if (!userId) {
            return;
        }
        if (!removals.has(userId)) {
            removals.set(userId, []);
        }
        removals.get(userId)?.push(token);
    });
    if (removals.size === 0) {
        return;
    }
    const batch = db.batch();
    removals.forEach((tokens, userId) => {
        const ref = db.collection("users").doc(userId);
        batch.update(ref, {
            fcmTokens: firestore_1.FieldValue.arrayRemove(...tokens),
            updatedAt: firestore_1.FieldValue.serverTimestamp()
        });
    });
    await batch.commit();
};
const writeNotifications = async (db, userIds, payload) => {
    if (userIds.length == 0) {
        return;
    }
    for (const userChunk of chunk(userIds, 400)) {
        const batch = db.batch();
        userChunk.forEach((userId) => {
            const ref = db.collection("users").doc(userId).collection("notifications").doc();
            batch.set(ref, {
                title: payload.title,
                body: payload.body,
                route: payload.route,
                type: payload.type,
                data: payload.data ?? {},
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp()
            });
        });
        await batch.commit();
    }
};
const getUnreadCount = async (db, userId, cache) => {
    if (cache.has(userId)) {
        return cache.get(userId) ?? 0;
    }
    const snapshot = await db
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .where("isRead", "==", false)
        .get();
    const count = snapshot.size ?? 0;
    cache.set(userId, count);
    return count;
};
const sendNotificationWithBadge = async (db, title, body, tokens, route, data = {}, tokenUserMap, summary) => {
    if (tokens.length == 0) {
        return;
    }
    const sendChunk = async (tokenChunk, badge) => {
        summary && (summary.sends += 1);
        const message = {
            notification: { title, body },
            data: { route, ...data },
            tokens: tokenChunk
        };
        if (badge !== undefined) {
            message.apns = {
                payload: {
                    aps: {
                        badge
                    }
                }
            };
        }
        const response = await admin.messaging().sendEachForMulticast(message);
        await cleanupInvalidTokens(db, tokenChunk, response, tokenUserMap);
        if (summary) {
            summary.successCount += response.successCount;
            summary.failureCount += response.failureCount;
            response.responses.forEach((item, index) => {
                if (!item.success) {
                    summary.failures.push({
                        token: tokenChunk[index] ?? "",
                        code: item.error?.code,
                        message: item.error?.message
                    });
                }
            });
        }
    };
    if (!tokenUserMap) {
        for (const tokenChunk of chunk(tokens, 500)) {
            await sendChunk(tokenChunk);
        }
        return;
    }
    const tokensByUser = new Map();
    const unknownTokens = [];
    tokens.forEach((token) => {
        const userId = tokenUserMap.get(token);
        if (!userId) {
            unknownTokens.push(token);
            return;
        }
        if (!tokensByUser.has(userId)) {
            tokensByUser.set(userId, []);
        }
        tokensByUser.get(userId)?.push(token);
    });
    if (unknownTokens.length > 0) {
        for (const tokenChunk of chunk(unknownTokens, 500)) {
            await sendChunk(tokenChunk);
        }
    }
    const badgeCache = new Map();
    for (const [userId, userTokens] of tokensByUser.entries()) {
        const badge = await getUnreadCount(db, userId, badgeCache);
        for (const tokenChunk of chunk(userTokens, 500)) {
            await sendChunk(tokenChunk, badge);
        }
    }
};
const runBillingReminders = async (includeDiagnostics, allowedUserIds) => {
    const db = admin.firestore();
    const now = new Date();
    const inFiveDays = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000);
    const maxDate = firestore_1.Timestamp.fromDate(inFiveDays);
    const userDocs = [];
    if (allowedUserIds && allowedUserIds.size > 0) {
        for (const userId of allowedUserIds) {
            const doc = await db.collection("users").doc(userId).get();
            if (doc.exists) {
                userDocs.push(doc);
            }
        }
    }
    else {
        const usersSnapshot = await db.collection("users").get();
        userDocs.push(...usersSnapshot.docs);
    }
    const summary = {
        maxDateISO: inFiveDays.toISOString(),
        usersScanned: userDocs.length,
        usersWithTokens: 0,
        subscriptionsScanned: 0,
        subscriptionsMatched: 0,
        groupsScanned: 0,
        groupsMatched: 0,
        groupsMissingNextBillingDateCount: 0,
        groupsNonTimestampCount: 0,
        missingNextBillingDateCount: 0,
        nonTimestampCount: 0,
        nextBillingDateTypes: {},
        remindersByOffset: {
            "0": 0,
            "1": 0,
            "2": 0,
            "5": 0
        },
        groupsReset: 0,
        groupsOverdue: 0,
        groupOffsetDebug: [],
        sends: 0,
        successCount: 0,
        failureCount: 0,
        failures: []
    };
    const timeZone = "America/Sao_Paulo";
    const startOfDayUtc = (date) => {
        const formatter = new Intl.DateTimeFormat("en-US", {
            timeZone,
            year: "numeric",
            month: "2-digit",
            day: "2-digit"
        });
        const parts = formatter.formatToParts(date);
        const year = Number(parts.find((part) => part.type === "year")?.value);
        const month = Number(parts.find((part) => part.type === "month")?.value);
        const day = Number(parts.find((part) => part.type === "day")?.value);
        return Date.UTC(year, month - 1, day);
    };
    const offsetDays = (date) => {
        const todayUtc = startOfDayUtc(now);
        const targetUtc = startOfDayUtc(date);
        return Math.round((targetUtc - todayUtc) / (24 * 60 * 60 * 1000));
    };
    const validOffsets = new Set([0, 2, 5]);
    const subscriptionOffsets = new Set([0, 1, 2, 5]);
    const reminderTextForOffset = (offset) => {
        if (offset === 0) {
            return "vence hoje.";
        }
        if (offset === 1) {
            return "vence amanha.";
        }
        if (offset === 2) {
            return "vence em 2 dias.";
        }
        return "vence em 5 dias.";
    };
    const daysBetween = (from, to) => {
        const fromUtc = startOfDayUtc(from);
        const toUtc = startOfDayUtc(to);
        return Math.round((toUtc - fromUtc) / (24 * 60 * 60 * 1000));
    };
    const sendOverdueRemindersIfNeeded = async (groupDoc, newlyOverdueMemberIds) => {
        const data = groupDoc.data();
        const groupName = data.name || "Grupo";
        const ownerId = data.ownerId;
        const groupRef = groupDoc.ref;
        const membersSnapshot = await groupRef.collection("members").get();
        const now = new Date();
        const remindMemberUserIds = [];
        const remindMemberNames = [];
        const batch = db.batch();
        let hasMissingOverdueDate = false;
        membersSnapshot.docs.forEach((memberDoc) => {
            const memberData = memberDoc.data();
            const userId = memberData.userId;
            const status = memberData.status ?? "pending";
            const paymentMode = data.paymentMode ?? "split";
            const isOwner = ownerId && userId == ownerId;
            if (!userId || (paymentMode !== "rotation" && isOwner) || status != "overdue") {
                return;
            }
            if (newlyOverdueMemberIds.has(memberDoc.id)) {
                return;
            }
            const overdueStartedAt = memberData.overdueStartedAt;
            if (!overdueStartedAt) {
                batch.update(memberDoc.ref, {
                    overdueStartedAt: firestore_1.FieldValue.serverTimestamp(),
                    updatedAt: firestore_1.FieldValue.serverTimestamp()
                });
                hasMissingOverdueDate = true;
                return;
            }
            const daysSince = daysBetween(overdueStartedAt.toDate(), now);
            if (daysSince < 1 || daysSince > 2) {
                return;
            }
            remindMemberUserIds.push(userId);
            remindMemberNames.push(memberData.name ?? "Membro");
        });
        if (hasMissingOverdueDate) {
            await batch.commit();
        }
        if (remindMemberUserIds.length == 0) {
            return;
        }
        const memberSnapshots = await Promise.all(Array.from(new Set(remindMemberUserIds)).map((userId) => db.collection("users").doc(userId).get()));
        const memberTokens = new Set();
        const tokenUserMap = new Map();
        memberSnapshots.forEach((snapshot) => {
            const tokens = snapshot.data()?.fcmTokens || [];
            tokens.forEach((token) => {
                memberTokens.add(token);
                tokenUserMap.set(token, snapshot.id);
            });
        });
        const memberBody = `Seu pagamento do grupo ${groupName} continua em atraso.`;
        await writeNotifications(db, remindMemberUserIds, {
            title: "Pagamento em atraso",
            body: memberBody,
            route: "groups",
            type: "member_overdue",
            data: { groupId: groupDoc.id }
        });
        if (memberTokens.size > 0) {
            await sendNotification("Pagamento em atraso", memberBody, Array.from(memberTokens), "groups", { groupId: groupDoc.id }, tokenUserMap);
        }
        if (ownerId) {
            const ownerSnapshot = await db.collection("users").doc(ownerId).get();
            const ownerTokens = ownerSnapshot.data()?.fcmTokens || [];
            const uniqueNames = Array.from(new Set(remindMemberNames));
            const list = uniqueNames.length <= 3
                ? uniqueNames.join(", ")
                : `${uniqueNames.slice(0, 3).join(", ")} e mais ${uniqueNames.length - 3}`;
            const body = uniqueNames.length == 1
                ? `${list} continua em atraso no grupo ${groupName}.`
                : `${list} continuam em atraso no grupo ${groupName}.`;
            await writeNotifications(db, [ownerId], {
                title: "Pagamento em atraso",
                body,
                route: "groups",
                type: "owner_overdue",
                data: { groupId: groupDoc.id, targetUserId: ownerId }
            });
            if (ownerTokens.length > 0) {
                const ownerTokenMap = new Map();
                ownerTokens.forEach((token) => ownerTokenMap.set(token, ownerId));
                await sendNotification("Pagamento em atraso", body, ownerTokens, "groups", { groupId: groupDoc.id, targetUserId: ownerId }, ownerTokenMap);
            }
        }
    };
    const sendNotification = async (title, body, tokens, route, data = {}, tokenUserMap) => {
        await sendNotificationWithBadge(db, title, body, tokens, route, data, tokenUserMap, summary);
    };
    const resetGroupStatusesIfNeeded = async (groupDoc, nextBillingDate, offset) => {
        if (offset !== 5) {
            return;
        }
        const data = groupDoc.data();
        const lastReset = data.lastChargeResetDate;
        if (lastReset && lastReset.toMillis() == nextBillingDate.toMillis()) {
            return;
        }
        const ownerId = data.ownerId;
        const groupRef = groupDoc.ref;
        const membersSnapshot = await groupRef.collection("members").get();
        const paymentMode = data.paymentMode ?? "split";
        const batch = db.batch();
        if (paymentMode !== "rotation") {
            membersSnapshot.docs.forEach((memberDoc) => {
                const memberData = memberDoc.data();
                const role = memberData.role ?? "";
                const userId = memberData.userId;
                const isOwner = role == "owner" || (ownerId && userId == ownerId);
                if (isOwner) {
                    return;
                }
                batch.update(memberDoc.ref, {
                    status: "pending",
                    overdueStartedAt: firestore_1.FieldValue.delete(),
                    receiptURL: firestore_1.FieldValue.delete(),
                    submittedAt: firestore_1.FieldValue.delete(),
                    approvedAt: firestore_1.FieldValue.delete(),
                    updatedAt: firestore_1.FieldValue.serverTimestamp()
                });
            });
            const preview = data.membersPreview ?? [];
            const updatedPreview = preview.map((member) => {
                const userId = member.userId;
                const isOwner = ownerId && userId == ownerId;
                if (isOwner) {
                    return member;
                }
                return {
                    ...member,
                    status: "pending",
                    receiptURL: null
                };
            });
            batch.update(groupRef, {
                membersPreview: updatedPreview,
                lastChargeResetDate: nextBillingDate,
                updatedAt: firestore_1.FieldValue.serverTimestamp()
            });
            await batch.commit();
            summary.groupsReset += 1;
            return;
        }
        const rotationOrder = Array.isArray(data.rotationOrder) ? data.rotationOrder : [];
        let rotationIndex = typeof data.rotationIndex === "number" ? data.rotationIndex : 0;
        let currentPayerId = data.currentPayerId
            ?? (rotationOrder[rotationIndex] ?? rotationOrder[0]);
        const rotationCycleStart = data.rotationCycleStartDate;
        const shouldAdvance = !rotationCycleStart || rotationCycleStart.toMillis() !== nextBillingDate.toMillis();
        if (rotationOrder.length > 0 && shouldAdvance) {
            const currentIndex = currentPayerId ? rotationOrder.indexOf(currentPayerId) : -1;
            const baseIndex = currentIndex >= 0 ? currentIndex : rotationIndex;
            const nextIndex = ((baseIndex >= 0 ? baseIndex : 0) + 1) % rotationOrder.length;
            rotationIndex = nextIndex;
            currentPayerId = rotationOrder[nextIndex];
        }
        membersSnapshot.docs.forEach((memberDoc) => {
            const memberData = memberDoc.data();
            const userId = memberData.userId;
            const isOwner = ownerId && userId == ownerId;
            const isCurrentPayer = Boolean(currentPayerId && (memberDoc.id === currentPayerId || (userId && userId === currentPayerId)));
            let nextStatus = isCurrentPayer ? "pending" : "exempt";
            if (isOwner && isCurrentPayer) {
                nextStatus = "paid";
            }
            batch.update(memberDoc.ref, {
                status: nextStatus,
                overdueStartedAt: firestore_1.FieldValue.delete(),
                receiptURL: firestore_1.FieldValue.delete(),
                submittedAt: firestore_1.FieldValue.delete(),
                approvedAt: firestore_1.FieldValue.delete(),
                updatedAt: firestore_1.FieldValue.serverTimestamp()
            });
        });
        const preview = data.membersPreview ?? [];
        const updatedPreview = preview.map((member) => {
            const memberId = member.id;
            const userId = member.userId;
            const isOwner = ownerId && userId == ownerId;
            const isCurrentPayer = Boolean(currentPayerId &&
                (memberId === currentPayerId || (userId && userId === currentPayerId)));
            let nextStatus = isCurrentPayer ? "pending" : "exempt";
            if (isOwner && isCurrentPayer) {
                nextStatus = "paid";
            }
            return {
                ...member,
                status: nextStatus,
                receiptURL: null
            };
        });
        const groupUpdate = {
            membersPreview: updatedPreview,
            lastChargeResetDate: nextBillingDate,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            rotationIndex,
            currentPayerId: currentPayerId ?? null,
            rotationCycleStartDate: nextBillingDate
        };
        batch.update(groupRef, groupUpdate);
        await batch.commit();
        summary.groupsReset += 1;
    };
    const markGroupStatusesOverdueIfNeeded = async (groupDoc, offset, force = false) => {
        if (!force && offset >= 0) {
            return { memberIds: [], userIds: [], names: [] };
        }
        const data = groupDoc.data();
        const ownerId = data.ownerId;
        const groupRef = groupDoc.ref;
        const membersSnapshot = await groupRef.collection("members").get();
        const paymentMode = data.paymentMode ?? "split";
        let hasMemberUpdates = false;
        const overdueMemberIds = [];
        const overdueMemberUserIds = [];
        const overdueMemberNames = [];
        const batch = db.batch();
        membersSnapshot.docs.forEach((memberDoc) => {
            const memberData = memberDoc.data();
            const userId = memberData.userId;
            const status = memberData.status ?? "pending";
            if ((paymentMode !== "rotation" && ownerId && userId == ownerId) || status !== "pending") {
                return;
            }
            hasMemberUpdates = true;
            overdueMemberIds.push(memberDoc.id);
            if (userId) {
                overdueMemberUserIds.push(userId);
            }
            overdueMemberNames.push(memberData.name ?? "Membro");
            batch.update(memberDoc.ref, {
                status: "overdue",
                overdueStartedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp()
            });
        });
        const preview = data.membersPreview ?? [];
        let previewChanged = false;
        const updatedPreview = preview.map((member) => {
            const status = member.status ?? "pending";
            if ((paymentMode !== "rotation" && ownerId && member.userId == ownerId) || status !== "pending") {
                return member;
            }
            previewChanged = true;
            return {
                ...member,
                status: "overdue"
            };
        });
        if (!hasMemberUpdates && !previewChanged) {
            return { memberIds: [], userIds: [], names: [] };
        }
        batch.update(groupRef, {
            membersPreview: updatedPreview,
            updatedAt: firestore_1.FieldValue.serverTimestamp()
        });
        await batch.commit();
        summary.groupsOverdue += 1;
        const memberUserIds = membersSnapshot.docs
            .filter((memberDoc) => overdueMemberIds.includes(memberDoc.id))
            .map((memberDoc) => memberDoc.data().userId)
            .filter((userId) => Boolean(userId));
        if (memberUserIds.length > 0) {
            const memberSnapshots = await Promise.all(memberUserIds.map((userId) => db.collection("users").doc(userId).get()));
            const memberTokens = new Set();
            const tokenUserMap = new Map();
            memberSnapshots.forEach((snapshot) => {
                const tokens = snapshot.data()?.fcmTokens || [];
                tokens.forEach((token) => {
                    memberTokens.add(token);
                    tokenUserMap.set(token, snapshot.id);
                });
            });
            const memberBody = `Seu pagamento do grupo ${data.name || "Grupo"} está em atraso.`;
            await writeNotifications(db, memberUserIds, {
                title: "Pagamento em atraso",
                body: memberBody,
                route: "groups",
                type: "member_overdue",
                data: { groupId: groupDoc.id }
            });
            if (memberTokens.size > 0) {
                await sendNotification("Pagamento em atraso", memberBody, Array.from(memberTokens), "groups", { groupId: groupDoc.id }, tokenUserMap);
            }
        }
        if (ownerId) {
            const ownerSnapshot = await db.collection("users").doc(ownerId).get();
            const ownerTokens = ownerSnapshot.data()?.fcmTokens || [];
            const count = overdueMemberIds.length;
            const memberList = overdueMemberNames.length <= 3
                ? overdueMemberNames.join(", ")
                : `${overdueMemberNames.slice(0, 3).join(", ")} e mais ${overdueMemberNames.length - 3}`;
            const body = count == 1
                ? `${memberList} está em atraso no grupo ${data.name || "Grupo"}.`
                : `${memberList} estão em atraso no grupo ${data.name || "Grupo"}.`;
            if (ownerTokens.length > 0) {
                const ownerTokenMap = new Map();
                ownerTokens.forEach((token) => ownerTokenMap.set(token, ownerId));
                await writeNotifications(db, [ownerId], {
                    title: "Pagamento em atraso",
                    body,
                    route: "groups",
                    type: "owner_overdue",
                    data: { groupId: groupDoc.id, targetUserId: ownerId }
                });
                await sendNotification("Pagamento em atraso", body, ownerTokens, "groups", { groupId: groupDoc.id, targetUserId: ownerId }, ownerTokenMap);
            }
            else {
                await writeNotifications(db, [ownerId], {
                    title: "Pagamento em atraso",
                    body,
                    route: "groups",
                    type: "owner_overdue",
                    data: { groupId: groupDoc.id, targetUserId: ownerId }
                });
            }
        }
        return {
            memberIds: overdueMemberIds,
            userIds: overdueMemberUserIds.length > 0 ? overdueMemberUserIds : memberUserIds,
            names: overdueMemberNames
        };
    };
    for (const userDoc of userDocs) {
        const tokens = userDoc.data()?.fcmTokens || [];
        if (tokens.length > 0) {
            summary.usersWithTokens += 1;
        }
        if (includeDiagnostics) {
            const allSubsSnapshot = await db
                .collection("users")
                .doc(userDoc.id)
                .collection("subscriptions")
                .get();
            summary.subscriptionsScanned += allSubsSnapshot.size;
            for (const sub of allSubsSnapshot.docs) {
                const data = sub.data();
                const nextBillingDate = data.nextBillingDate;
                if (!nextBillingDate) {
                    summary.missingNextBillingDateCount += 1;
                    continue;
                }
                const typeName = nextBillingDate.constructor?.name ?? typeof nextBillingDate;
                summary.nextBillingDateTypes[typeName] = (summary.nextBillingDateTypes[typeName] ?? 0) + 1;
                if (!(nextBillingDate instanceof firestore_1.Timestamp)) {
                    summary.nonTimestampCount += 1;
                }
            }
        }
        const subsSnapshot = await db
            .collection("users")
            .doc(userDoc.id)
            .collection("subscriptions")
            .where("nextBillingDate", "<=", maxDate)
            .get();
        if (subsSnapshot.empty) {
            continue;
        }
        summary.subscriptionsMatched += subsSnapshot.size;
        for (const sub of subsSnapshot.docs) {
            const data = sub.data();
            const status = (data.status ?? "active").toLowerCase();
            if (status !== "active") {
                continue;
            }
            const nextBillingDate = data.nextBillingDate;
            if (!nextBillingDate) {
                continue;
            }
            const offset = offsetDays(nextBillingDate.toDate());
            if (!subscriptionOffsets.has(offset)) {
                continue;
            }
            const name = data.name || "Assinatura";
            const body = `Sua assinatura de ${name} ${reminderTextForOffset(offset)}`;
            const tokenUserMap = new Map();
            tokens.forEach((token) => tokenUserMap.set(token, userDoc.id));
            await writeNotifications(db, [userDoc.id], {
                title: "Cobranca em breve",
                body,
                route: "subscriptions",
                type: "subscription_reminder",
                data: { subscriptionId: sub.id }
            });
            if (tokens.length > 0) {
                await sendNotification("Cobranca em breve", body, tokens, "subscriptions", { subscriptionId: sub.id }, tokenUserMap);
            }
            summary.remindersByOffset[String(offset)] += 1;
        }
    }
    const groupsCollection = db.collection("groups");
    const allowedUserList = allowedUserIds ? Array.from(allowedUserIds) : [];
    const baseChargeQuery = groupsCollection.where("chargeNextBillingDate", "<=", maxDate);
    const baseSubscriptionQuery = groupsCollection.where("subscriptionNextBillingDate", "<=", maxDate);
    const applyAllowedFilter = (query) => {
        if (!allowedUserIds || allowedUserIds.size == 0) {
            return query;
        }
        if (allowedUserList.length == 1) {
            return query.where("memberIds", "array-contains", allowedUserList[0]);
        }
        return query.where("memberIds", "array-contains-any", allowedUserList.slice(0, 10));
    };
    const groupsByChargeSnapshot = await applyAllowedFilter(baseChargeQuery).get();
    const groupsBySubscriptionSnapshot = await applyAllowedFilter(baseSubscriptionQuery).get();
    const matchedGroups = new Map();
    groupsByChargeSnapshot.docs.forEach((doc) => matchedGroups.set(doc.id, doc));
    groupsBySubscriptionSnapshot.docs.forEach((doc) => matchedGroups.set(doc.id, doc));
    summary.groupsMatched = matchedGroups.size;
    if (includeDiagnostics) {
        const allGroupsSnapshot = await applyAllowedFilter(groupsCollection).get();
        summary.groupsScanned = allGroupsSnapshot.size;
        for (const groupDoc of allGroupsSnapshot.docs) {
            const data = groupDoc.data();
            const nextBillingDate = data.subscriptionNextBillingDate;
            if (!nextBillingDate) {
                summary.groupsMissingNextBillingDateCount += 1;
                continue;
            }
            if (!(nextBillingDate instanceof firestore_1.Timestamp)) {
                summary.groupsNonTimestampCount += 1;
            }
        }
    }
    for (const groupDoc of matchedGroups.values()) {
        const data = groupDoc.data();
        const subscriptionStatus = data.subscriptionStatus?.toLowerCase();
        const isLinkedSubscriptionPausedOrCanceled = Boolean(data.subscriptionId) &&
            subscriptionStatus !== undefined &&
            subscriptionStatus !== "active";
        if (isLinkedSubscriptionPausedOrCanceled) {
            continue;
        }
        const groupName = data.name || "Grupo";
        const nextBillingDate = data.chargeNextBillingDate ||
            data.subscriptionNextBillingDate;
        if (!nextBillingDate) {
            if (includeDiagnostics) {
                summary.groupOffsetDebug.push({ groupId: groupDoc.id });
            }
            continue;
        }
        const offset = offsetDays(nextBillingDate.toDate());
        if (includeDiagnostics) {
            summary.groupOffsetDebug.push({
                groupId: groupDoc.id,
                nextBillingISO: nextBillingDate.toDate().toISOString(),
                offset
            });
        }
        const newlyOverdue = await markGroupStatusesOverdueIfNeeded(groupDoc, offset);
        await sendOverdueRemindersIfNeeded(groupDoc, new Set(newlyOverdue.memberIds));
        if (!validOffsets.has(offset)) {
            continue;
        }
        await resetGroupStatusesIfNeeded(groupDoc, nextBillingDate, offset);
        const memberIds = data.memberIds ?? [];
        let targetMemberIds = allowedUserIds
            ? memberIds.filter((id) => allowedUserIds.has(id))
            : memberIds;
        const paymentMode = data.paymentMode ?? "split";
        if (paymentMode === "rotation") {
            const currentPayerId = data.currentPayerId;
            const preview = data.membersPreview ?? [];
            const payerUserId = preview.find((member) => {
                const id = member.id;
                const userId = member.userId;
                return id === currentPayerId || userId === currentPayerId;
            })?.userId;
            targetMemberIds = payerUserId ? [payerUserId] : [];
        }
        if (targetMemberIds.length == 0) {
            continue;
        }
        const userSnapshots = await Promise.all(targetMemberIds.map((userId) => db.collection("users").doc(userId).get()));
        const tokens = new Set();
        const tokenUserMap = new Map();
        for (const userSnapshot of userSnapshots) {
            const userTokens = userSnapshot.data()?.fcmTokens || [];
            userTokens.forEach((token) => {
                tokens.add(token);
                tokenUserMap.set(token, userSnapshot.id);
            });
        }
        const body = `O grupo ${groupName} ${reminderTextForOffset(offset)}`;
        await writeNotifications(db, targetMemberIds, {
            title: "Cobranca em breve",
            body,
            route: "groups",
            type: "group_reminder",
            data: { groupId: groupDoc.id }
        });
        if (tokens.size > 0) {
            await sendNotification("Cobranca em breve", body, Array.from(tokens), "groups", { groupId: groupDoc.id }, tokenUserMap);
        }
        summary.remindersByOffset[String(offset)] += 1;
    }
    return summary;
};
exports.sendBillingReminders = (0, scheduler_1.onSchedule)({ schedule: "every day 09:00", timeZone: "America/Sao_Paulo" }, async () => {
    const summary = await runBillingReminders(false, null);
    console.log("sendBillingReminders summary", summary);
});
exports.sendBillingRemindersTest = (0, https_1.onRequest)(async (req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(403).send("Apenas no emulator.");
        return;
    }
    const targetUserId = req.query.userId?.trim();
    const allowedUserIds = targetUserId ? new Set([targetUserId]) : null;
    const summary = await runBillingReminders(true, allowedUserIds);
    res.status(200).json(summary);
});
exports.markOverdueTest = (0, https_1.onRequest)(async (req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(403).send("Apenas no emulator.");
        return;
    }
    const groupId = req.query.groupId || req.body?.groupId;
    const targetUserId = req.query.userId?.trim();
    if (!groupId) {
        res.status(400).json({ error: "groupId é obrigatório." });
        return;
    }
    const db = admin.firestore();
    const groupSnapshot = await db.collection("groups").doc(groupId).get();
    if (!groupSnapshot.exists) {
        res.status(404).json({ error: "Grupo não encontrado." });
        return;
    }
    const summary = {
        maxDateISO: new Date().toISOString(),
        usersScanned: 0,
        usersWithTokens: 0,
        subscriptionsScanned: 0,
        subscriptionsMatched: 0,
        groupsScanned: 1,
        groupsMatched: 1,
        groupsMissingNextBillingDateCount: 0,
        groupsNonTimestampCount: 0,
        missingNextBillingDateCount: 0,
        nonTimestampCount: 0,
        nextBillingDateTypes: {},
        remindersByOffset: {
            "0": 0,
            "1": 0,
            "2": 0,
            "5": 0
        },
        groupsReset: 0,
        groupsOverdue: 0,
        groupOffsetDebug: [],
        sends: 0,
        successCount: 0,
        failureCount: 0,
        failures: []
    };
    const sendNotification = async (title, body, tokens, route, data = {}, tokenUserMap) => {
        await sendNotificationWithBadge(db, title, body, tokens, route, data, tokenUserMap, summary);
    };
    const data = groupSnapshot.data() ?? {};
    const ownerId = data.ownerId;
    const groupRef = groupSnapshot.ref;
    const membersSnapshot = await groupRef.collection("members").get();
    let hasMemberUpdates = false;
    const overdueMemberIds = [];
    const overdueMemberNames = [];
    const batch = db.batch();
    membersSnapshot.docs.forEach((memberDoc) => {
        const memberData = memberDoc.data();
        const role = memberData.role ?? "";
        const userId = memberData.userId;
        const isOwner = role == "owner" || (ownerId && userId == ownerId);
        const status = memberData.status ?? "pending";
        if (isOwner || status !== "pending") {
            return;
        }
        hasMemberUpdates = true;
        overdueMemberIds.push(memberDoc.id);
        overdueMemberNames.push(memberData.name ?? "Membro");
        batch.update(memberDoc.ref, {
            status: "overdue",
            overdueStartedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp()
        });
    });
    const preview = data.membersPreview ?? [];
    let previewChanged = false;
    const updatedPreview = preview.map((member) => {
        const userId = member.userId;
        const isOwner = ownerId && userId == ownerId;
        const status = member.status ?? "pending";
        if (isOwner || status !== "pending") {
            return member;
        }
        previewChanged = true;
        return {
            ...member,
            status: "overdue"
        };
    });
    if (!hasMemberUpdates && !previewChanged) {
        res.status(200).json({ message: "Nenhum membro pendente para marcar como atraso." });
        return;
    }
    batch.update(groupRef, {
        membersPreview: updatedPreview,
        updatedAt: firestore_1.FieldValue.serverTimestamp()
    });
    await batch.commit();
    summary.groupsOverdue += 1;
    const memberUserIds = membersSnapshot.docs
        .filter((memberDoc) => overdueMemberIds.includes(memberDoc.id))
        .map((memberDoc) => memberDoc.data().userId)
        .filter((userId) => Boolean(userId));
    const filteredMemberUserIds = targetUserId
        ? memberUserIds.filter((id) => id == targetUserId)
        : memberUserIds;
    if (filteredMemberUserIds.length > 0) {
        const memberSnapshots = await Promise.all(filteredMemberUserIds.map((userId) => db.collection("users").doc(userId).get()));
        const memberTokens = new Set();
        memberSnapshots.forEach((snapshot) => {
            const tokens = snapshot.data()?.fcmTokens || [];
            tokens.forEach((token) => memberTokens.add(token));
        });
        if (memberTokens.size > 0) {
            const tokenUserMap = new Map();
            memberSnapshots.forEach((snapshot) => {
                const userTokens = snapshot.data()?.fcmTokens || [];
                userTokens.forEach((token) => tokenUserMap.set(token, snapshot.id));
            });
            await sendNotification("Pagamento em atraso", `Seu pagamento do grupo ${data.name || "Grupo"} está em atraso.`, Array.from(memberTokens), "groups", { groupId }, tokenUserMap);
        }
        await writeNotifications(db, filteredMemberUserIds, {
            title: "Pagamento em atraso",
            body: `Seu pagamento do grupo ${data.name || "Grupo"} está em atraso.`,
            route: "groups",
            type: "member_overdue",
            data: { groupId }
        });
    }
    if (ownerId && (!targetUserId || ownerId == targetUserId)) {
        const ownerSnapshot = await db.collection("users").doc(ownerId).get();
        const ownerTokens = ownerSnapshot.data()?.fcmTokens || [];
        const count = overdueMemberIds.length;
        const memberList = overdueMemberNames.length <= 3
            ? overdueMemberNames.join(", ")
            : `${overdueMemberNames.slice(0, 3).join(", ")} e mais ${overdueMemberNames.length - 3}`;
        const body = count == 1
            ? `${memberList} está em atraso no grupo ${data.name || "Grupo"}.`
            : `${memberList} estão em atraso no grupo ${data.name || "Grupo"}.`;
        await writeNotifications(db, [ownerId], {
            title: "Pagamento em atraso",
            body,
            route: "groups",
            type: "owner_overdue",
            data: { groupId, targetUserId: ownerId }
        });
        if (ownerTokens.length > 0) {
            const tokenUserMap = new Map();
            ownerTokens.forEach((token) => tokenUserMap.set(token, ownerId));
            await sendNotification("Pagamento em atraso", body, ownerTokens, "groups", { groupId, targetUserId: ownerId }, tokenUserMap);
        }
    }
    res.status(200).json(summary);
});
exports.notifyOwnerOnPaymentSubmitted = (0, firestore_2.onDocumentUpdated)("groups/{groupId}/members/{memberId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
        return;
    }
    if (after.status != "submitted") {
        return;
    }
    // Ignora se já estava submitted e a URL não mudou (evita duplicidade se atualizar outro campo)
    if (before.status == "submitted" && before.receiptURL == after.receiptURL) {
        return;
    }
    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
        return;
    }
    let ownerId = groupData.ownerId;
    if (!ownerId) {
        const ownerSnapshot = await groupSnapshot.ref
            .collection("members")
            .where("role", "==", "owner")
            .limit(1)
            .get();
        ownerId = ownerSnapshot.docs[0]?.data().userId;
    }
    if (!ownerId) {
        return;
    }
    const ownerSnapshot = await admin.firestore().collection("users").doc(ownerId).get();
    const tokens = ownerSnapshot.data()?.fcmTokens || [];
    const tokenUserMap = new Map();
    tokens.forEach((token) => tokenUserMap.set(token, ownerId));
    const memberName = after.name || "Membro";
    const groupName = groupData.name || "Grupo";
    const title = "Pagamento enviado";
    const body = `${memberName} enviou o comprovante do grupo ${groupName}.`;
    await writeNotifications(admin.firestore(), [ownerId], {
        title,
        body,
        route: "groups",
        type: "payment_submitted",
        data: { groupId, targetUserId: ownerId }
    });
    if (tokens.length == 0) {
        return;
    }
    await sendNotificationWithBadge(admin.firestore(), title, body, tokens, "groups", { groupId, targetUserId: ownerId }, tokenUserMap);
});
exports.notifyMemberOnPaymentStatusChanged = (0, firestore_2.onDocumentUpdated)("groups/{groupId}/members/{memberId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
        return;
    }
    const beforeStatus = before.status;
    const afterStatus = after.status;
    if (!beforeStatus || !afterStatus || beforeStatus == afterStatus) {
        return;
    }
    // Only notify when admin approves or rejects a submitted payment.
    if (afterStatus == "paid") {
        // ok
    }
    else if (afterStatus == "pending" && beforeStatus == "submitted") {
        // treated as rejection
    }
    else {
        return;
    }
    const memberUserId = after.userId;
    if (!memberUserId) {
        return;
    }
    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
        return;
    }
    const ownerId = groupData.ownerId;
    if (ownerId && ownerId == memberUserId) {
        return;
    }
    const groupName = groupData.name ?? "Grupo";
    const title = afterStatus == "paid" ? "Pagamento aprovado" : "Pagamento reprovado";
    const body = afterStatus == "paid"
        ? `Seu pagamento no grupo ${groupName} foi aprovado.`
        : `Seu pagamento no grupo ${groupName} foi reprovado. Revise e envie novamente.`;
    await writeNotifications(admin.firestore(), [memberUserId], {
        title,
        body,
        route: "groups",
        type: afterStatus == "paid" ? "payment_approved" : "payment_rejected",
        data: { groupId }
    });
    const memberSnapshot = await admin.firestore().collection("users").doc(memberUserId).get();
    const tokens = memberSnapshot.data()?.fcmTokens || [];
    if (tokens.length == 0) {
        return;
    }
    const tokenUserMap = new Map();
    tokens.forEach((token) => tokenUserMap.set(token, memberUserId));
    await sendNotificationWithBadge(admin.firestore(), title, body, tokens, "groups", { groupId, targetUserId: memberUserId }, tokenUserMap);
});
exports.notifyOwnerOnMemberJoined = (0, firestore_2.onDocumentCreated)("groups/{groupId}/members/{memberId}", async (event) => {
    const created = event.data?.data();
    if (!created) {
        return;
    }
    const role = created.role ?? "";
    if (role == "owner") {
        return;
    }
    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
        return;
    }
    const ownerId = groupData.ownerId;
    const memberUserId = created.userId;
    if (!ownerId || ownerId == memberUserId) {
        return;
    }
    const memberName = created.name ?? "Um membro";
    const groupName = groupData.name ?? "Grupo";
    const title = "Novo membro no grupo";
    const body = `${memberName} entrou no grupo ${groupName}.`;
    await writeNotifications(admin.firestore(), [ownerId], {
        title,
        body,
        route: "groups",
        type: "member_joined",
        data: { groupId, targetUserId: ownerId }
    });
    const ownerSnapshot = await admin.firestore().collection("users").doc(ownerId).get();
    const tokens = ownerSnapshot.data()?.fcmTokens || [];
    if (tokens.length == 0) {
        return;
    }
    const tokenUserMap = new Map();
    tokens.forEach((token) => tokenUserMap.set(token, ownerId));
    await sendNotificationWithBadge(admin.firestore(), title, body, tokens, "groups", { groupId, targetUserId: ownerId }, tokenUserMap);
});
exports.notifyOwnerOnMemberLeft = (0, firestore_2.onDocumentDeleted)("groups/{groupId}/members/{memberId}", async (event) => {
    const deleted = event.data?.data();
    if (!deleted) {
        return;
    }
    const role = deleted.role ?? "";
    if (role == "owner") {
        return;
    }
    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
        return;
    }
    const ownerId = groupData.ownerId;
    const memberUserId = deleted.userId;
    if (!ownerId || ownerId == memberUserId) {
        return;
    }
    const memberName = deleted.name ?? "Um membro";
    const groupName = groupData.name ?? "Grupo";
    const title = "Membro saiu do grupo";
    const body = `${memberName} saiu do grupo ${groupName}.`;
    await writeNotifications(admin.firestore(), [ownerId], {
        title,
        body,
        route: "groups",
        type: "member_left",
        data: { groupId, targetUserId: ownerId }
    });
    const ownerSnapshot = await admin.firestore().collection("users").doc(ownerId).get();
    const tokens = ownerSnapshot.data()?.fcmTokens || [];
    if (tokens.length == 0) {
        return;
    }
    const tokenUserMap = new Map();
    tokens.forEach((token) => tokenUserMap.set(token, ownerId));
    await sendNotificationWithBadge(admin.firestore(), title, body, tokens, "groups", { groupId, targetUserId: ownerId }, tokenUserMap);
});
exports.notifyOwnerOnPaymentSubmittedTest = (0, https_1.onRequest)(async (req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(403).send("Apenas no emulator.");
        return;
    }
    const groupId = req.query.groupId || req.body?.groupId;
    const memberId = req.query.memberId || req.body?.memberId;
    const targetUserId = req.query.userId?.trim();
    const summary = {
        maxDateISO: new Date().toISOString(),
        usersScanned: 0,
        usersWithTokens: 0,
        subscriptionsScanned: 0,
        subscriptionsMatched: 0,
        groupsScanned: 0,
        groupsMatched: 0,
        groupsMissingNextBillingDateCount: 0,
        groupsNonTimestampCount: 0,
        missingNextBillingDateCount: 0,
        nonTimestampCount: 0,
        nextBillingDateTypes: {},
        remindersByOffset: {},
        groupsReset: 0,
        groupsOverdue: 0,
        groupOffsetDebug: [],
        sends: 0,
        successCount: 0,
        failureCount: 0,
        failures: []
    };
    if (!groupId || !memberId) {
        res.status(400).json({ error: "groupId e memberId são obrigatórios." });
        return;
    }
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
        res.status(404).json({ error: "Grupo não encontrado." });
        return;
    }
    const ownerId = groupData.ownerId;
    if (!ownerId) {
        res.status(400).json({ error: "ownerId ausente no grupo." });
        return;
    }
    const memberSnapshot = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .doc(memberId)
        .get();
    const memberData = memberSnapshot.data();
    if (!memberData) {
        res.status(404).json({ error: "Membro não encontrado." });
        return;
    }
    const ownerSnapshot = await admin.firestore().collection("users").doc(ownerId).get();
    const tokens = ownerSnapshot.data()?.fcmTokens || [];
    const memberName = memberData.name || "Membro";
    const groupName = groupData.name || "Grupo";
    const title = "Pagamento enviado";
    const body = `${memberName} enviou o comprovante do grupo ${groupName}.`;
    if (targetUserId && targetUserId !== ownerId) {
        const overrideSnapshot = await admin.firestore().collection("users").doc(targetUserId).get();
        const overrideTokens = overrideSnapshot.data()?.fcmTokens || [];
        const tokenUserMap = new Map();
        overrideTokens.forEach((token) => tokenUserMap.set(token, targetUserId));
        await writeNotifications(admin.firestore(), [targetUserId], {
            title,
            body,
            route: "groups",
            type: "payment_submitted",
            data: { groupId, targetUserId }
        });
        if (overrideTokens.length == 0) {
            res.status(200).json({ message: "Usuário alvo sem tokens." });
            return;
        }
        await sendNotificationWithBadge(admin.firestore(), title, body, overrideTokens, "groups", { groupId, targetUserId }, tokenUserMap, summary);
        res.status(200).json({
            successCount: summary.successCount,
            failureCount: summary.failureCount
        });
        return;
    }
    await writeNotifications(admin.firestore(), [ownerId], {
        title,
        body,
        route: "groups",
        type: "payment_submitted",
        data: { groupId, targetUserId: ownerId }
    });
    if (tokens.length == 0) {
        res.status(200).json({ message: "Owner sem tokens." });
        return;
    }
    const tokenUserMap = new Map();
    tokens.forEach((token) => tokenUserMap.set(token, ownerId));
    await sendNotificationWithBadge(admin.firestore(), title, body, tokens, "groups", { groupId, targetUserId: ownerId }, tokenUserMap, summary);
    res.status(200).json({
        successCount: summary.successCount,
        failureCount: summary.failureCount
    });
});
