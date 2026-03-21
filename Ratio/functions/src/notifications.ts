import * as admin from "firebase-admin";
import {
  FieldValue,
  QueryDocumentSnapshot,
  Timestamp
} from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
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

const getUnreadCount = async (
  db: FirebaseFirestore.Firestore,
  userId: string,
  cache: Map<string, number>
): Promise<number> => {
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

const sendNotificationWithBadge = async (
  db: FirebaseFirestore.Firestore,
  title: string,
  body: string,
  tokens: string[],
  route: NotificationRoute,
  data: Record<string, string> = {},
  tokenUserMap?: Map<string, string>,
  summary?: ReminderSummary
) => {
  if (tokens.length == 0) {
    return;
  }

  const sendChunk = async (tokenChunk: string[], badge?: number) => {
    summary && (summary.sends += 1);
    const message: admin.messaging.MulticastMessage = {
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

  const tokensByUser = new Map<string, string[]>();
  const unknownTokens: string[] = [];
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

  const badgeCache = new Map<string, number>();
  for (const [userId, userTokens] of tokensByUser.entries()) {
    const badge = await getUnreadCount(db, userId, badgeCache);
    for (const tokenChunk of chunk(userTokens, 500)) {
      await sendChunk(tokenChunk, badge);
    }
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

  const daysBetween = (from: Date, to: Date): number => {
    const fromUtc = startOfDayUtc(from);
    const toUtc = startOfDayUtc(to);
    return Math.round((toUtc - fromUtc) / (24 * 60 * 60 * 1000));
  };

  const sendOverdueRemindersIfNeeded = async (
    groupDoc: QueryDocumentSnapshot,
    newlyOverdueMemberIds: Set<string>
  ) => {
    const data = groupDoc.data();
    const groupName = data.name || "Grupo";
    const ownerId = data.ownerId as string | undefined;
    const groupRef = groupDoc.ref;
    const membersSnapshot = await groupRef.collection("members").get();

    const now = new Date();
    const remindMemberUserIds: string[] = [];
    const remindMemberNames: string[] = [];
    const batch = db.batch();
    let hasMissingOverdueDate = false;

    membersSnapshot.docs.forEach((memberDoc) => {
      const memberData = memberDoc.data();
      const userId = memberData.userId as string | undefined;
      const status = (memberData.status as string | undefined) ?? "pending";
      const paymentMode = (data.paymentMode as string | undefined) ?? "split";
      const isOwner = ownerId && userId == ownerId;

      if (!userId || (paymentMode !== "rotation" && isOwner) || status != "overdue") {
        return;
      }
      if (newlyOverdueMemberIds.has(memberDoc.id)) {
        return;
      }

      const overdueStartedAt = memberData.overdueStartedAt as Timestamp | undefined;
      if (!overdueStartedAt) {
        batch.update(memberDoc.ref, {
          overdueStartedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
        hasMissingOverdueDate = true;
        return;
      }

      const daysSince = daysBetween(overdueStartedAt.toDate(), now);
      if (daysSince < 1 || daysSince > 2) {
        return;
      }

      remindMemberUserIds.push(userId);
      remindMemberNames.push((memberData.name as string | undefined) ?? "Membro");
    });

    if (hasMissingOverdueDate) {
      await batch.commit();
    }

    if (remindMemberUserIds.length == 0) {
      return;
    }

    const memberSnapshots = await Promise.all(
      Array.from(new Set(remindMemberUserIds)).map((userId) => db.collection("users").doc(userId).get())
    );
    const memberTokens = new Set<string>();
    const tokenUserMap = new Map<string, string>();
    memberSnapshots.forEach((snapshot) => {
      const tokens: string[] = snapshot.data()?.fcmTokens || [];
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
      await sendNotification(
        "Pagamento em atraso",
        memberBody,
        Array.from(memberTokens),
        "groups",
        { groupId: groupDoc.id },
        tokenUserMap
      );
    }

    if (ownerId) {
      const ownerSnapshot = await db.collection("users").doc(ownerId).get();
      const ownerTokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
      const uniqueNames = Array.from(new Set(remindMemberNames));
      const list =
        uniqueNames.length <= 3
          ? uniqueNames.join(", ")
          : `${uniqueNames.slice(0, 3).join(", ")} e mais ${uniqueNames.length - 3}`;
      const body =
        uniqueNames.length == 1
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
        const ownerTokenMap = new Map<string, string>();
        ownerTokens.forEach((token) => ownerTokenMap.set(token, ownerId));
        await sendNotification(
          "Pagamento em atraso",
          body,
          ownerTokens,
          "groups",
          { groupId: groupDoc.id, targetUserId: ownerId },
          ownerTokenMap
        );
      }
    }
  };

  const sendNotification = async (
    title: string,
    body: string,
    tokens: string[],
    route: NotificationRoute,
    data: Record<string, string> = {},
    tokenUserMap?: Map<string, string>
  ) => {
    await sendNotificationWithBadge(
      db,
      title,
      body,
      tokens,
      route,
      data,
      tokenUserMap,
      summary
    );
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
    const paymentMode = (data.paymentMode as string | undefined) ?? "split";

    const batch = db.batch();

    if (paymentMode !== "rotation") {
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
          overdueStartedAt: FieldValue.delete(),
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
      return;
    }

    const rotationOrder = Array.isArray(data.rotationOrder) ? (data.rotationOrder as string[]) : [];
    let rotationIndex = typeof data.rotationIndex === "number" ? (data.rotationIndex as number) : 0;
    let currentPayerId = (data.currentPayerId as string | undefined)
      ?? (rotationOrder[rotationIndex] ?? rotationOrder[0]);
    const rotationCycleStart = data.rotationCycleStartDate as Timestamp | undefined;
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
      const userId = memberData.userId as string | undefined;
      const isOwner = ownerId && userId == ownerId;
      const isCurrentPayer = Boolean(
        currentPayerId && (memberDoc.id === currentPayerId || (userId && userId === currentPayerId))
      );
      let nextStatus = isCurrentPayer ? "pending" : "exempt";
      if (isOwner && isCurrentPayer) {
        nextStatus = "paid";
      }
      batch.update(memberDoc.ref, {
        status: nextStatus,
        overdueStartedAt: FieldValue.delete(),
        receiptURL: FieldValue.delete(),
        submittedAt: FieldValue.delete(),
        approvedAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp()
      });
    });

    const preview = (data.membersPreview as Array<Record<string, any>> | undefined) ?? [];
    const updatedPreview = preview.map((member) => {
      const memberId = member.id as string | undefined;
      const userId = member.userId as string | undefined;
      const isOwner = ownerId && userId == ownerId;
      const isCurrentPayer = Boolean(
        currentPayerId &&
        (memberId === currentPayerId || (userId && userId === currentPayerId))
      );
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

    const groupUpdate: Record<string, any> = {
      membersPreview: updatedPreview,
      lastChargeResetDate: nextBillingDate,
      updatedAt: FieldValue.serverTimestamp(),
      rotationIndex,
      currentPayerId: currentPayerId ?? null,
      rotationCycleStartDate: nextBillingDate
    };

    batch.update(groupRef, groupUpdate);

    await batch.commit();
    summary.groupsReset += 1;
  };

  const markGroupStatusesOverdueIfNeeded = async (
    groupDoc: QueryDocumentSnapshot,
    offset: number,
    force: boolean = false
  ): Promise<{
    memberIds: string[];
    userIds: string[];
    names: string[];
  }> => {
    if (!force && offset >= 0) {
      return { memberIds: [], userIds: [], names: [] };
    }

    const data = groupDoc.data();
    const ownerId = data.ownerId as string | undefined;
    const groupRef = groupDoc.ref;
    const membersSnapshot = await groupRef.collection("members").get();
    const paymentMode = (data.paymentMode as string | undefined) ?? "split";

    let hasMemberUpdates = false;
    const overdueMemberIds: string[] = [];
    const overdueMemberUserIds: string[] = [];
    const overdueMemberNames: string[] = [];
    const batch = db.batch();

    membersSnapshot.docs.forEach((memberDoc) => {
      const memberData = memberDoc.data();
      const userId = memberData.userId as string | undefined;
      const status = (memberData.status as string | undefined) ?? "pending";

      if ((paymentMode !== "rotation" && ownerId && userId == ownerId) || status !== "pending") {
        return;
      }

      hasMemberUpdates = true;
      overdueMemberIds.push(memberDoc.id);
      if (userId) {
        overdueMemberUserIds.push(userId);
      }
      overdueMemberNames.push((memberData.name as string | undefined) ?? "Membro");
      batch.update(memberDoc.ref, {
        status: "overdue",
        overdueStartedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
    });

    const preview = (data.membersPreview as Array<Record<string, any>> | undefined) ?? [];
    let previewChanged = false;
    const updatedPreview = preview.map((member) => {
      const status = (member.status as string | undefined) ?? "pending";

      if ((paymentMode !== "rotation" && ownerId && (member.userId as string | undefined) == ownerId) || status !== "pending") {
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
    const tokenUserMap = new Map<string, string>();
    memberSnapshots.forEach((snapshot) => {
      const tokens: string[] = snapshot.data()?.fcmTokens || [];
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
        await sendNotification(
          "Pagamento em atraso",
          memberBody,
          Array.from(memberTokens),
          "groups",
          { groupId: groupDoc.id },
          tokenUserMap
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
          : `${overdueMemberNames.slice(0, 3).join(", ")} e mais ${overdueMemberNames.length - 3
          }`;
      const body =
        count == 1
          ? `${memberList} está em atraso no grupo ${data.name || "Grupo"}.`
          : `${memberList} estão em atraso no grupo ${data.name || "Grupo"}.`;

      if (ownerTokens.length > 0) {
        const ownerTokenMap = new Map<string, string>();
        ownerTokens.forEach((token) => ownerTokenMap.set(token, ownerId));
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
          { groupId: groupDoc.id, targetUserId: ownerId },
          ownerTokenMap
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
    return {
      memberIds: overdueMemberIds,
      userIds: overdueMemberUserIds.length > 0 ? overdueMemberUserIds : memberUserIds,
      names: overdueMemberNames
    };
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
      const status = ((data.status as string | undefined) ?? "active").toLowerCase();
      if (status !== "active") {
        continue;
      }
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
    const subscriptionStatus = (data.subscriptionStatus as string | undefined)?.toLowerCase();
    const isLinkedSubscriptionPausedOrCanceled =
      Boolean(data.subscriptionId) &&
      subscriptionStatus !== undefined &&
      subscriptionStatus !== "active";
    if (isLinkedSubscriptionPausedOrCanceled) {
      continue;
    }
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
    const newlyOverdue = await markGroupStatusesOverdueIfNeeded(groupDoc, offset);
    await sendOverdueRemindersIfNeeded(groupDoc, new Set(newlyOverdue.memberIds));
    if (!validOffsets.has(offset)) {
      continue;
    }

    await resetGroupStatusesIfNeeded(groupDoc, nextBillingDate, offset);

    const memberIds = (data.memberIds as string[] | undefined) ?? [];
    let targetMemberIds = allowedUserIds
      ? memberIds.filter((id) => allowedUserIds.has(id))
      : memberIds;

    const paymentMode = (data.paymentMode as string | undefined) ?? "split";
    if (paymentMode === "rotation") {
      const currentPayerId = data.currentPayerId as string | undefined;
      const preview = (data.membersPreview as Array<Record<string, any>> | undefined) ?? [];
      const payerUserId = preview.find((member) => {
        const id = member.id as string | undefined;
        const userId = member.userId as string | undefined;
        return id === currentPayerId || userId === currentPayerId;
      })?.userId as string | undefined;

      targetMemberIds = payerUserId ? [payerUserId] : [];
    }

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
    const summary = await runBillingReminders(false, null);
    console.log("sendBillingReminders summary", summary);
  }
);

export const sendBillingRemindersTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }
  const targetUserId = (req.query.userId as string | undefined)?.trim();
  const allowedUserIds = targetUserId ? new Set([targetUserId]) : null;
  const summary = await runBillingReminders(true, allowedUserIds);
  res.status(200).json(summary);
});

export const markOverdueTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }

  const groupId = (req.query.groupId as string) || (req.body?.groupId as string);
  const targetUserId = (req.query.userId as string | undefined)?.trim();
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
    await sendNotificationWithBadge(
      db,
      title,
      body,
      tokens,
      route,
      data,
      tokenUserMap,
      summary
    );
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
      overdueStartedAt: FieldValue.serverTimestamp(),
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

  const filteredMemberUserIds = targetUserId
    ? memberUserIds.filter((id) => id == targetUserId)
    : memberUserIds;
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

  if (ownerId && (!targetUserId || ownerId == targetUserId)) {
    const ownerSnapshot = await db.collection("users").doc(ownerId).get();
    const ownerTokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
    const count = overdueMemberIds.length;
    const memberList =
      overdueMemberNames.length <= 3
        ? overdueMemberNames.join(", ")
        : `${overdueMemberNames.slice(0, 3).join(", ")} e mais ${overdueMemberNames.length - 3
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

    await sendNotificationWithBadge(
      admin.firestore(),
      title,
      body,
      tokens,
      "groups",
      { groupId, targetUserId: ownerId },
      tokenUserMap
    );
  }
);

export const notifyMemberOnPaymentStatusChanged = onDocumentUpdated(
  "groups/{groupId}/members/{memberId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;
    if (!beforeStatus || !afterStatus || beforeStatus == afterStatus) {
      return;
    }

    // Only notify when admin approves or rejects a submitted payment.
    if (afterStatus == "paid") {
      // ok
    } else if (afterStatus == "pending" && beforeStatus == "submitted") {
      // treated as rejection
    } else {
      return;
    }

    const memberUserId = after.userId as string | undefined;
    if (!memberUserId) {
      return;
    }

    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
      return;
    }

    const ownerId = groupData.ownerId as string | undefined;
    if (ownerId && ownerId == memberUserId) {
      return;
    }

    const groupName = (groupData.name as string | undefined) ?? "Grupo";
    const title = afterStatus == "paid" ? "Pagamento aprovado" : "Pagamento reprovado";
    const body =
      afterStatus == "paid"
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
    const tokens: string[] = memberSnapshot.data()?.fcmTokens || [];
    if (tokens.length == 0) {
      return;
    }

    const tokenUserMap = new Map<string, string>();
    tokens.forEach((token) => tokenUserMap.set(token, memberUserId));
    await sendNotificationWithBadge(
      admin.firestore(),
      title,
      body,
      tokens,
      "groups",
      { groupId, targetUserId: memberUserId },
      tokenUserMap
    );
  }
);

export const notifyOwnerOnMemberJoined = onDocumentCreated(
  "groups/{groupId}/members/{memberId}",
  async (event) => {
    const created = event.data?.data();
    if (!created) {
      return;
    }

    const role = (created.role as string | undefined) ?? "";
    if (role == "owner") {
      return;
    }

    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
      return;
    }

    const ownerId = groupData.ownerId as string | undefined;
    const memberUserId = created.userId as string | undefined;
    if (!ownerId || ownerId == memberUserId) {
      return;
    }

    const memberName = (created.name as string | undefined) ?? "Um membro";
    const groupName = (groupData.name as string | undefined) ?? "Grupo";
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
    const tokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
    if (tokens.length == 0) {
      return;
    }

    const tokenUserMap = new Map<string, string>();
    tokens.forEach((token) => tokenUserMap.set(token, ownerId));
    await sendNotificationWithBadge(
      admin.firestore(),
      title,
      body,
      tokens,
      "groups",
      { groupId, targetUserId: ownerId },
      tokenUserMap
    );
  }
);

export const notifyOwnerOnMemberLeft = onDocumentDeleted(
  "groups/{groupId}/members/{memberId}",
  async (event) => {
    const deleted = event.data?.data();
    if (!deleted) {
      return;
    }

    const role = (deleted.role as string | undefined) ?? "";
    if (role == "owner") {
      return;
    }

    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
      return;
    }

    const ownerId = groupData.ownerId as string | undefined;
    const memberUserId = deleted.userId as string | undefined;
    if (!ownerId || ownerId == memberUserId) {
      return;
    }

    const memberName = (deleted.name as string | undefined) ?? "Um membro";
    const groupName = (groupData.name as string | undefined) ?? "Grupo";
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
    const tokens: string[] = ownerSnapshot.data()?.fcmTokens || [];
    if (tokens.length == 0) {
      return;
    }

    const tokenUserMap = new Map<string, string>();
    tokens.forEach((token) => tokenUserMap.set(token, ownerId));
    await sendNotificationWithBadge(
      admin.firestore(),
      title,
      body,
      tokens,
      "groups",
      { groupId, targetUserId: ownerId },
      tokenUserMap
    );
  }
);

export const notifyOwnerOnPaymentSubmittedTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }

  const groupId = (req.query.groupId as string) || (req.body?.groupId as string);
  const memberId = (req.query.memberId as string) || (req.body?.memberId as string);
  const targetUserId = (req.query.userId as string | undefined)?.trim();

  const summary: ReminderSummary = {
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

  if (targetUserId && targetUserId !== ownerId) {
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
    await sendNotificationWithBadge(
      admin.firestore(),
      title,
      body,
      overrideTokens,
      "groups",
      { groupId, targetUserId },
      tokenUserMap,
      summary
    );
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

  const tokenUserMap = new Map<string, string>();
  tokens.forEach((token) => tokenUserMap.set(token, ownerId));
  await sendNotificationWithBadge(
    admin.firestore(),
    title,
    body,
    tokens,
    "groups",
    { groupId, targetUserId: ownerId },
    tokenUserMap,
    summary
  );

  res.status(200).json({
    successCount: summary.successCount,
    failureCount: summary.failureCount
  });
});
