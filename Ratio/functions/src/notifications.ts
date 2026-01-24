import * as admin from "firebase-admin";
import {
  FieldValue,
  QueryDocumentSnapshot,
  Timestamp
} from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

type ReminderSummary = {
  maxDateISO: string;
  usersScanned: number;
  usersWithTokens: number;
  subscriptionsScanned: number;
  subscriptionsMatched: number;
  groupsScanned: number;
  groupsMatched: number;
  groupsMissingNextBillingDateCount: number;
  groupsNonTimestampCount: number;
  missingNextBillingDateCount: number;
  nonTimestampCount: number;
  nextBillingDateTypes: Record<string, number>;
  remindersByOffset: Record<string, number>;
  groupsReset: number;
  groupsOverdue: number;
  groupOffsetDebug: Array<{
    groupId: string;
    nextBillingISO?: string;
    offset?: number;
  }>;
  sends: number;
  successCount: number;
  failureCount: number;
  failures: Array<{ token: string; code?: string; message?: string }>;
};

type NotificationRoute = "groups" | "subscriptions" | "home" | "settings";
type NotificationPayload = {
  title: string;
  body: string;
  route: NotificationRoute;
  type: string;
  data?: Record<string, string>;
};

const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument"
]);

const chunk = <T,>(items: T[], size: number): T[][] => {
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
};

const cleanupInvalidTokens = async (
  db: FirebaseFirestore.Firestore,
  tokenChunk: string[],
  responses: admin.messaging.BatchResponse,
  tokenUserMap?: Map<string, string>
) => {
  if (!tokenUserMap) {
    return;
  }

  const removals = new Map<string, string[]>();
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
      fcmTokens: FieldValue.arrayRemove(...tokens),
      updatedAt: FieldValue.serverTimestamp()
    });
  });
  await batch.commit();
};

const writeNotifications = async (
  db: FirebaseFirestore.Firestore,
  userIds: string[],
  payload: NotificationPayload
) => {
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
        createdAt: FieldValue.serverTimestamp()
      });
    });
    await batch.commit();
  }
};

const runBillingReminders = async (
  includeDiagnostics: boolean,
  allowedUserIds: Set<string> | null
): Promise<ReminderSummary> => {
  const db = admin.firestore();
  const now = new Date();
  const inFiveDays = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000);
  const maxDate = Timestamp.fromDate(inFiveDays);

  const userDocs: FirebaseFirestore.DocumentSnapshot[] = [];
  if (allowedUserIds && allowedUserIds.size > 0) {
    for (const userId of allowedUserIds) {
      const doc = await db.collection("users").doc(userId).get();
      if (doc.exists) {
        userDocs.push(doc);
      }
    }
  } else {
    const usersSnapshot = await db.collection("users").get();
    userDocs.push(...usersSnapshot.docs);
  }
  const summary: ReminderSummary = {
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
  const startOfDayUtc = (date: Date): number => {
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

  const offsetDays = (date: Date): number => {
    const todayUtc = startOfDayUtc(now);
    const targetUtc = startOfDayUtc(date);
    return Math.round((targetUtc - todayUtc) / (24 * 60 * 60 * 1000));
  };

  const validOffsets = new Set([0, 2, 5]);
  const subscriptionOffsets = new Set([0, 1, 2, 5]);

  const reminderTextForOffset = (offset: number): string => {
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

  const sendNotification = async (
    title: string,
    body: string,
    tokens: string[],
    route: NotificationRoute,
    data: Record<string, string> = {},
    tokenUserMap?: Map<string, string>
  ) => {
    summary.sends += 1;
    for (const tokenChunk of chunk(tokens, 500)) {
      const response = await admin.messaging().sendEachForMulticast({
        notification: { title, body },
        data: { route, ...data },
        tokens: tokenChunk
      });
      await cleanupInvalidTokens(db, tokenChunk, response, tokenUserMap);
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

  const resetGroupStatusesIfNeeded = async (
    groupDoc: QueryDocumentSnapshot,
    nextBillingDate: Timestamp,
    offset: number
  ) => {
    if (offset !== 5) {
      return;
    }

    const data = groupDoc.data();
    const lastReset = data.lastChargeResetDate as Timestamp | undefined;
    if (lastReset && lastReset.toMillis() == nextBillingDate.toMillis()) {
      return;
    }

    const ownerId = data.ownerId as string | undefined;
    const groupRef = groupDoc.ref;
    const membersSnapshot = await groupRef.collection("members").get();

    const batch = db.batch();
    membersSnapshot.docs.forEach((memberDoc) => {
      const memberData = memberDoc.data();
      const role = (memberData.role as string | undefined) ?? "";
      const userId = memberData.userId as string | undefined;
      const isOwner = role == "owner" || (ownerId && userId == ownerId);

      if (isOwner) {
        return;
      }

      batch.update(memberDoc.ref, {
        status: "pending",
        receiptURL: FieldValue.delete(),
        submittedAt: FieldValue.delete(),
        approvedAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp()
      });
    });

    const preview = (data.membersPreview as Array<Record<string, any>> | undefined) ?? [];
    const updatedPreview = preview.map((member) => {
      const userId = member.userId as string | undefined;
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
      updatedAt: FieldValue.serverTimestamp()
    });

    await batch.commit();
    summary.groupsReset += 1;
  };

  const markGroupStatusesOverdueIfNeeded = async (
    groupDoc: QueryDocumentSnapshot,
    offset: number,
    force: boolean = false
  ) => {
    if (!force && offset >= 0) {
      return;
    }

    const data = groupDoc.data();
    const ownerId = data.ownerId as string | undefined;
    const groupRef = groupDoc.ref;
    const membersSnapshot = await groupRef.collection("members").get();

    let hasMemberUpdates = false;
    const overdueMemberIds: string[] = [];
    const overdueMemberNames: string[] = [];
    const batch = db.batch();

    membersSnapshot.docs.forEach((memberDoc) => {
      const memberData = memberDoc.data();
      const role = (memberData.role as string | undefined) ?? "";
      const userId = memberData.userId as string | undefined;
      const isOwner = role == "owner" || (ownerId && userId == ownerId);
      const status = (memberData.status as string | undefined) ?? "pending";

      if (isOwner || status !== "pending") {
        return;
      }

      hasMemberUpdates = true;
      overdueMemberIds.push(memberDoc.id);
      overdueMemberNames.push((memberData.name as string | undefined) ?? "Membro");
      batch.update(memberDoc.ref, {
        status: "overdue",
        updatedAt: FieldValue.serverTimestamp()
      });
    });

    const preview = (data.membersPreview as Array<Record<string, any>> | undefined) ?? [];
    let previewChanged = false;
    const updatedPreview = preview.map((member) => {
      const userId = member.userId as string | undefined;
      const isOwner = ownerId && userId == ownerId;
      const status = (member.status as string | undefined) ?? "pending";

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
      return;
    }

    batch.update(groupRef, {
      membersPreview: updatedPreview,
      updatedAt: FieldValue.serverTimestamp()
    });

    await batch.commit();
    summary.groupsOverdue += 1;

    const memberUserIds = membersSnapshot.docs
      .filter((memberDoc) => overdueMemberIds.includes(memberDoc.id))
      .map((memberDoc) => memberDoc.data().userId as string | undefined)
      .filter((userId): userId is string => Boolean(userId));

    if (memberUserIds.length > 0) {
      const memberSnapshots = await Promise.all(
        memberUserIds.map((userId) => db.collection("users").doc(userId).get())
      );
      const memberTokens = new Set<string>();
      memberSnapshots.forEach((snapshot) => {
        const tokens: string[] = snapshot.data()?.fcmTokens || [];
        tokens.forEach((token) => memberTokens.add(token));
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
        await sendNotification(
          "Pagamento em atraso",
          memberBody,
          Array.from(memberTokens),
          "groups",
          { groupId: groupDoc.id }
        );
      }
    }

    if (ownerId) {
      const ownerSnapshot = await db.collection("users").doc(ownerId).get();
      const ownerTokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
      const count = overdueMemberIds.length;
      const memberList =
        overdueMemberNames.length <= 3
          ? overdueMemberNames.join(", ")
          : `${overdueMemberNames.slice(0, 3).join(", ")} e mais ${
              overdueMemberNames.length - 3
            }`;
      const body =
        count == 1
          ? `${memberList} está em atraso no grupo ${data.name || "Grupo"}.`
          : `${memberList} estão em atraso no grupo ${data.name || "Grupo"}.`;

      if (ownerTokens.length > 0) {
        await writeNotifications(db, [ownerId], {
          title: "Pagamento em atraso",
          body,
          route: "groups",
          type: "owner_overdue",
          data: { groupId: groupDoc.id, targetUserId: ownerId }
        });
        await sendNotification(
          "Pagamento em atraso",
          body,
          ownerTokens,
          "groups",
          { groupId: groupDoc.id, targetUserId: ownerId }
        );
      } else {
        await writeNotifications(db, [ownerId], {
          title: "Pagamento em atraso",
          body,
          route: "groups",
          type: "owner_overdue",
          data: { groupId: groupDoc.id, targetUserId: ownerId }
        });
      }
    }
  };

  for (const userDoc of userDocs) {
    const tokens: string[] = userDoc.data()?.fcmTokens || [];
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

        if (!(nextBillingDate instanceof Timestamp)) {
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
      const nextBillingDate = data.nextBillingDate as Timestamp | undefined;
      if (!nextBillingDate) {
        continue;
      }

      const offset = offsetDays(nextBillingDate.toDate());
      if (!subscriptionOffsets.has(offset)) {
        continue;
      }

      const name = data.name || "Assinatura";
      const body = `Sua assinatura de ${name} ${reminderTextForOffset(offset)}`;
      const tokenUserMap = new Map<string, string>();
      tokens.forEach((token) => tokenUserMap.set(token, userDoc.id));
      await writeNotifications(db, [userDoc.id], {
        title: "Cobranca em breve",
        body,
        route: "subscriptions",
        type: "subscription_reminder",
        data: { subscriptionId: sub.id }
      });
      if (tokens.length > 0) {
        await sendNotification(
          "Cobranca em breve",
          body,
          tokens,
          "subscriptions",
          { subscriptionId: sub.id },
          tokenUserMap
        );
      }
      summary.remindersByOffset[String(offset)] += 1;
    }
  }

  const groupsCollection = db.collection("groups");
  const allowedUserList = allowedUserIds ? Array.from(allowedUserIds) : [];
  const baseChargeQuery = groupsCollection.where("chargeNextBillingDate", "<=", maxDate);
  const baseSubscriptionQuery = groupsCollection.where("subscriptionNextBillingDate", "<=", maxDate);

  const applyAllowedFilter = (
    query: FirebaseFirestore.Query
  ): FirebaseFirestore.Query => {
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

  const matchedGroups = new Map<string, QueryDocumentSnapshot>();
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

      if (!(nextBillingDate instanceof Timestamp)) {
        summary.groupsNonTimestampCount += 1;
      }
    }
  }

  for (const groupDoc of matchedGroups.values()) {
    const data = groupDoc.data();
    const groupName = data.name || "Grupo";
    const nextBillingDate =
      (data.chargeNextBillingDate as Timestamp | undefined) ||
      (data.subscriptionNextBillingDate as Timestamp | undefined);
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
    if (!validOffsets.has(offset)) {
      await markGroupStatusesOverdueIfNeeded(groupDoc, offset);
      continue;
    }

    await markGroupStatusesOverdueIfNeeded(groupDoc, offset);
    await resetGroupStatusesIfNeeded(groupDoc, nextBillingDate, offset);

    const memberIds = (data.memberIds as string[] | undefined) ?? [];
    const targetMemberIds = allowedUserIds
      ? memberIds.filter((id) => allowedUserIds.has(id))
      : memberIds;

    if (targetMemberIds.length == 0) {
      continue;
    }

    const userSnapshots = await Promise.all(
      targetMemberIds.map((userId) => db.collection("users").doc(userId).get())
    );

    const tokens = new Set<string>();
    const tokenUserMap = new Map<string, string>();
    for (const userSnapshot of userSnapshots) {
      const userTokens: string[] = userSnapshot.data()?.fcmTokens || [];
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
      await sendNotification(
        "Cobranca em breve",
        body,
        Array.from(tokens),
        "groups",
        { groupId: groupDoc.id },
        tokenUserMap
      );
    }
    summary.remindersByOffset[String(offset)] += 1;
  }

  return summary;
};

export const sendBillingReminders = onSchedule(
  { schedule: "every day 09:00", timeZone: "America/Sao_Paulo" },
  async () => {
    const allowedUserIds = allowedUserIdsForEnv();
    const summary = await runBillingReminders(false, allowedUserIds);
    console.log("sendBillingReminders summary", summary);
  }
);

export const sendBillingRemindersTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }
  const allowedUserIds = new Set([resolveUserId(req.query.userId as string | undefined)]);
  const summary = await runBillingReminders(true, allowedUserIds);
  res.status(200).json(summary);
});

export const markOverdueTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }

  const groupId = (req.query.groupId as string) || (req.body?.groupId as string);
  const targetUserId = resolveUserId(req.query.userId as string | undefined);
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

  const summary: ReminderSummary = {
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

  const sendNotification = async (
    title: string,
    body: string,
    tokens: string[],
    route: NotificationRoute,
    data: Record<string, string> = {},
    tokenUserMap?: Map<string, string>
  ) => {
    summary.sends += 1;
    for (const tokenChunk of chunk(tokens, 500)) {
      const response = await admin.messaging().sendEachForMulticast({
        notification: { title, body },
        data: { route, ...data },
        tokens: tokenChunk
      });
      await cleanupInvalidTokens(db, tokenChunk, response, tokenUserMap);
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

  const data = groupSnapshot.data() ?? {};
  const ownerId = data.ownerId as string | undefined;
  const groupRef = groupSnapshot.ref;
  const membersSnapshot = await groupRef.collection("members").get();

  let hasMemberUpdates = false;
  const overdueMemberIds: string[] = [];
  const overdueMemberNames: string[] = [];
  const batch = db.batch();

  membersSnapshot.docs.forEach((memberDoc) => {
    const memberData = memberDoc.data();
    const role = (memberData.role as string | undefined) ?? "";
    const userId = memberData.userId as string | undefined;
    const isOwner = role == "owner" || (ownerId && userId == ownerId);
    const status = (memberData.status as string | undefined) ?? "pending";

    if (isOwner || status !== "pending") {
      return;
    }

    hasMemberUpdates = true;
    overdueMemberIds.push(memberDoc.id);
    overdueMemberNames.push((memberData.name as string | undefined) ?? "Membro");
    batch.update(memberDoc.ref, {
      status: "overdue",
      updatedAt: FieldValue.serverTimestamp()
    });
  });

  const preview = (data.membersPreview as Array<Record<string, any>> | undefined) ?? [];
  let previewChanged = false;
  const updatedPreview = preview.map((member) => {
    const userId = member.userId as string | undefined;
    const isOwner = ownerId && userId == ownerId;
    const status = (member.status as string | undefined) ?? "pending";

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
    updatedAt: FieldValue.serverTimestamp()
  });

  await batch.commit();
  summary.groupsOverdue += 1;

  const memberUserIds = membersSnapshot.docs
    .filter((memberDoc) => overdueMemberIds.includes(memberDoc.id))
    .map((memberDoc) => memberDoc.data().userId as string | undefined)
    .filter((userId): userId is string => Boolean(userId));

  const filteredMemberUserIds = memberUserIds.filter((id) => id == targetUserId);
  if (filteredMemberUserIds.length > 0) {
    const memberSnapshots = await Promise.all(
      filteredMemberUserIds.map((userId) => db.collection("users").doc(userId).get())
    );
    const memberTokens = new Set<string>();
    memberSnapshots.forEach((snapshot) => {
      const tokens: string[] = snapshot.data()?.fcmTokens || [];
      tokens.forEach((token) => memberTokens.add(token));
    });

    if (memberTokens.size > 0) {
      const tokenUserMap = new Map<string, string>();
      memberSnapshots.forEach((snapshot) => {
        const userTokens: string[] = snapshot.data()?.fcmTokens || [];
        userTokens.forEach((token) => tokenUserMap.set(token, snapshot.id));
      });
      await sendNotification(
        "Pagamento em atraso",
        `Seu pagamento do grupo ${data.name || "Grupo"} está em atraso.`,
        Array.from(memberTokens),
        "groups",
        { groupId },
        tokenUserMap
      );
    }
    await writeNotifications(db, filteredMemberUserIds, {
      title: "Pagamento em atraso",
      body: `Seu pagamento do grupo ${data.name || "Grupo"} está em atraso.`,
      route: "groups",
      type: "member_overdue",
      data: { groupId }
    });
  }

  if (ownerId && ownerId == targetUserId) {
    const ownerSnapshot = await db.collection("users").doc(ownerId).get();
    const ownerTokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
    const count = overdueMemberIds.length;
    const memberList =
      overdueMemberNames.length <= 3
        ? overdueMemberNames.join(", ")
        : `${overdueMemberNames.slice(0, 3).join(", ")} e mais ${
            overdueMemberNames.length - 3
          }`;
    const body =
      count == 1
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
      const tokenUserMap = new Map<string, string>();
      ownerTokens.forEach((token) => tokenUserMap.set(token, ownerId));
      await sendNotification(
        "Pagamento em atraso",
        body,
        ownerTokens,
        "groups",
        { groupId, targetUserId: ownerId },
        tokenUserMap
      );
    }
  }

  res.status(200).json(summary);
});

export const notifyOwnerOnPaymentSubmitted = onDocumentUpdated(
  "groups/{groupId}/members/{memberId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    if (before.status == "submitted" || after.status != "submitted") {
      return;
    }

    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
      return;
    }

    let ownerId = groupData.ownerId as string | undefined;
    if (!ownerId) {
      const ownerSnapshot = await groupSnapshot.ref
        .collection("members")
        .where("role", "==", "owner")
        .limit(1)
        .get();
      ownerId = ownerSnapshot.docs[0]?.data().userId as string | undefined;
    }

    if (!ownerId) {
      return;
    }
    const allowedUserIds = allowedUserIdsForEnv();
    if (allowedUserIds.size > 0 && !allowedUserIds.has(ownerId)) {
      return;
    }

    const ownerSnapshot = await admin.firestore().collection("users").doc(ownerId).get();
    const tokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
    const tokenUserMap = new Map<string, string>();
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

    const response = await admin.messaging().sendEachForMulticast({
      notification: { title, body },
      data: { route: "groups", groupId, targetUserId: ownerId },
      tokens
    });
    await cleanupInvalidTokens(admin.firestore(), tokens, response, tokenUserMap);
  }
);

export const notifyOwnerOnPaymentSubmittedTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }

  const groupId = (req.query.groupId as string) || (req.body?.groupId as string);
  const memberId = (req.query.memberId as string) || (req.body?.memberId as string);
  const targetUserId = resolveUserId(req.query.userId as string | undefined);

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

  const ownerId = groupData.ownerId as string | undefined;
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
  const tokens: string[] = ownerSnapshot.data()?.fcmTokens || [];

  const memberName = memberData.name || "Membro";
  const groupName = groupData.name || "Grupo";
  const title = "Pagamento enviado";
  const body = `${memberName} enviou o comprovante do grupo ${groupName}.`;

  if (targetUserId !== ownerId) {
    const overrideSnapshot = await admin.firestore().collection("users").doc(targetUserId).get();
    const overrideTokens: string[] = overrideSnapshot.data()?.fcmTokens || [];
    const tokenUserMap = new Map<string, string>();
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
    const response = await admin.messaging().sendEachForMulticast({
      notification: { title, body },
      data: { route: "groups", groupId, targetUserId },
      tokens: overrideTokens
    });
    await cleanupInvalidTokens(admin.firestore(), overrideTokens, response, tokenUserMap);
    res.status(200).json({
      successCount: response.successCount,
      failureCount: response.failureCount
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

  const tokenUserMap = new Map<string, string>();
  tokens.forEach((token) => tokenUserMap.set(token, ownerId));
  const response = await admin.messaging().sendEachForMulticast({
    notification: { title, body },
    data: { route: "groups", groupId, targetUserId: ownerId },
    tokens
  });
  await cleanupInvalidTokens(admin.firestore(), tokens, response, tokenUserMap);

  res.status(200).json({
    successCount: response.successCount,
    failureCount: response.failureCount
  });
});
