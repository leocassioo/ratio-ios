import * as admin from "firebase-admin";
import { user as authUser, UserRecord } from "firebase-functions/v1/auth";

const deleteQueryDocs = async (
  snapshot: FirebaseFirestore.QuerySnapshot,
  writer: FirebaseFirestore.BulkWriter
) => {
  snapshot.docs.forEach((doc) => writer.delete(doc.ref));
};

const deleteCollection = async (
  query: FirebaseFirestore.Query,
  writer: FirebaseFirestore.BulkWriter
) => {
  const snapshot = await query.get();
  if (snapshot.empty) return;
  await deleteQueryDocs(snapshot, writer);
};

const deleteStoragePrefix = async (prefix: string) => {
  const bucket = admin.storage().bucket();
  try {
    await bucket.deleteFiles({ prefix });
  } catch (error) {
    console.warn(`storage cleanup failed for ${prefix}`, error);
  }
};

export const cleanupUserOnDelete = authUser().onDelete(async (user: UserRecord) => {
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
    const ownerId = data.ownerId as string | undefined;
    const memberIds = Array.isArray(data.memberIds) ? (data.memberIds as string[]) : [];
    const remainingIds = memberIds.filter((id) => id !== uid);

    const preview = Array.isArray(data.membersPreview)
      ? (data.membersPreview as Array<Record<string, unknown>>)
      : Array.isArray(data.members)
      ? (data.members as Array<Record<string, unknown>>)
      : [];
    const updatedPreview = preview.filter((member) => member.userId !== uid);

    if (ownerId === uid) {
      if (remainingIds.length === 0) {
        const membersSnapshot = await groupRef.collection("members").get();
        await deleteQueryDocs(membersSnapshot, writer);
        writer.delete(groupRef);
      } else {
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
    } else {
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
