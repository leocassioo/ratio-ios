import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

type HistoryType = "subscription" | "group";

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

const dateKey = (date: Date): string => {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  });
  return formatter.format(date).replace(/-/g, "");
};

const createHistoryEntry = async (
  userId: string,
  id: string,
  data: Record<string, any>
) => {
  const ref = admin.firestore().collection("users").doc(userId).collection("billingHistory").doc(id);
  try {
    await ref.create(data);
  } catch (error: any) {
    if (error?.code === 6) {
      return;
    }
    throw error;
  }
};

export const recordSubscriptionHistory = onSchedule(
  { schedule: "every day 09:10", timeZone },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const startUtc = startOfDayUtc(now);
    const endUtc = startUtc + 24 * 60 * 60 * 1000 - 1;
    const startDate = Timestamp.fromMillis(startUtc);
    const endDate = Timestamp.fromMillis(endUtc);
    const todayKey = dateKey(now);

    const usersSnapshot = await db.collection("users").get();
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const subsSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("subscriptions")
        .where("nextBillingDate", ">=", startDate)
        .where("nextBillingDate", "<=", endDate)
        .get();

      for (const subDoc of subsSnapshot.docs) {
        const data = subDoc.data();
        const title = (data.name as string) || "Assinatura";
        const amount = (data.amount as number) || 0;
        const currencyCode = (data.currencyCode as string) || "BRL";
        const occurredAt = data.nextBillingDate as Timestamp | undefined;
        const docId = `sub_${subDoc.id}_${todayKey}`;

        await createHistoryEntry(userId, docId, {
          type: "subscription" as HistoryType,
          title,
          amount,
          currencyCode,
          occurredAt: occurredAt ?? Timestamp.fromDate(now),
          subscriptionId: subDoc.id,
          createdAt: Timestamp.fromDate(now)
        });
      }
    }
  }
);

export const recordGroupPaymentHistory = onDocumentUpdated(
  "groups/{groupId}/members/{memberId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    if (before.status === "paid" || after.status !== "paid") {
      return;
    }

    const groupId = event.params.groupId;
    const groupSnapshot = await admin.firestore().collection("groups").doc(groupId).get();
    const groupData = groupSnapshot.data();
    if (!groupData) {
      return;
    }

    const ownerId = groupData.ownerId as string | undefined;
    const memberUserId = after.userId as string | undefined;
    const role = (after.role as string | undefined) ?? "";
    if (!memberUserId || memberUserId === ownerId || role === "owner") {
      return;
    }

    const occurredAt = (after.approvedAt as Timestamp | undefined) ?? Timestamp.fromDate(new Date());
    const docId = `grp_${groupId}_${memberUserId}_${dateKey(occurredAt.toDate())}`;
    const title = (groupData.name as string) || "Grupo";
    const amount = (after.amount as number) || 0;
    const currencyCode = (groupData.currencyCode as string) || "BRL";

    await createHistoryEntry(memberUserId, docId, {
      type: "group" as HistoryType,
      title,
      amount,
      currencyCode,
      occurredAt,
      groupId,
      memberId: event.params.memberId,
      createdAt: Timestamp.fromDate(new Date())
    });
  }
);

export const recordHistoryTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }

  const userId = (req.query.userId as string) || (req.body?.userId as string);
  const type = ((req.query.type as string) || (req.body?.type as string) || "subscription") as HistoryType;
  const title = (req.query.title as string) || (req.body?.title as string) || "Teste";
  const amountRaw = (req.query.amount as string) || (req.body?.amount as string) || "19.90";
  const currencyCode =
    (req.query.currencyCode as string) || (req.body?.currencyCode as string) || "BRL";

  if (!userId) {
    res.status(400).json({ error: "userId é obrigatório." });
    return;
  }

  const amount = Number(amountRaw);
  if (Number.isNaN(amount)) {
    res.status(400).json({ error: "amount inválido." });
    return;
  }

  const now = new Date();
  const docId = `test2_${type}_${dateKey(now)}`;

  await createHistoryEntry(userId, docId, {
    type,
    title,
    amount,
    currencyCode,
    occurredAt: Timestamp.fromDate(now),
    createdAt: Timestamp.fromDate(now)
  });

  res.status(200).json({ message: "Histórico criado.", id: docId });
});
