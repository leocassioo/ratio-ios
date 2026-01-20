import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";

type SeedOptions = {
  userId: string;
  months: number;
  reset: boolean;
  now: Date;
};

const isEmulator = (): boolean => {
  return Boolean(process.env.FUNCTIONS_EMULATOR) || Boolean(process.env.FIREBASE_EMULATOR_HUB);
};

const randomItem = <T,>(items: T[], random: () => number): T => {
  return items[Math.floor(random() * items.length)];
};

const makeRandom = (seed: number) => {
  let value = seed % 2147483647;
  return () => {
    value = (value * 48271) % 2147483647;
    return value / 2147483647;
  };
};

const parseOptions = (req: any): SeedOptions => {
  const userId = typeof req.query.userId === "string" ? req.query.userId : "";
  const monthsParam = typeof req.query.months === "string" ? Number(req.query.months) : 6;
  const resetParam = typeof req.query.reset === "string" ? req.query.reset : "false";
  const nowParam = typeof req.query.now === "string" ? req.query.now : "";

  const months = Number.isFinite(monthsParam) && monthsParam > 0 ? Math.min(monthsParam, 24) : 6;
  const reset = resetParam === "true" || resetParam === "1";
  const now = nowParam ? new Date(`${nowParam}T12:00:00Z`) : new Date();

  return { userId, months, reset, now };
};

const subscriptionTemplates = [
  { name: "Netflix", category: "streaming", period: "monthly" },
  { name: "Spotify", category: "streaming", period: "monthly" },
  { name: "GPT Plus", category: "software", period: "monthly" },
  { name: "Adobe CC", category: "software", period: "monthly" },
  { name: "SmartFit", category: "fitness", period: "monthly" },
  { name: "Google One", category: "utilities", period: "monthly" },
  { name: "Duolingo", category: "education", period: "yearly" },
  { name: "Prime Video", category: "streaming", period: "monthly" }
];

const groupTemplates = [
  { name: "Netflix Família", category: "streaming" },
  { name: "Spotify Duo", category: "streaming" },
  { name: "Setapp", category: "software" },
  { name: "Office 365", category: "software" }
];

const memberNames = ["Ana", "Bruno", "Camila", "Diego", "Erika", "Felipe"];

const buildMonthStarts = (months: number, now: Date): Date[] => {
  const calendar = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const result: Date[] = [];
  for (let offset = months - 1; offset >= 0; offset -= 1) {
    const date = new Date(calendar);
    date.setUTCMonth(date.getUTCMonth() - offset);
    result.push(date);
  }
  return result;
};

const ensureReset = async (db: FirebaseFirestore.Firestore, userId: string) => {
  const subscriptions = await db.collection("users").doc(userId).collection("subscriptions").get();
  const history = await db.collection("users").doc(userId).collection("billingHistory").get();
  const groups = await db.collection("groups").where("ownerId", "==", userId).get();

  const batch = db.batch();
  subscriptions.docs.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => batch.delete(doc.ref));
  history.docs.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => batch.delete(doc.ref));
  groups.docs.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => batch.delete(doc.ref));
  await batch.commit();

  for (const group of groups.docs) {
    const members = await group.ref.collection("members").get();
    const membersBatch = db.batch();
    members.docs.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => membersBatch.delete(doc.ref));
    await membersBatch.commit();
  }
};

const createSubscriptions = async (db: FirebaseFirestore.Firestore, options: SeedOptions, random: () => number) => {
  const subscriptionsRef = db.collection("users").doc(options.userId).collection("subscriptions");
  const items = subscriptionTemplates.slice(0, 6 + Math.floor(random() * 3));
  const batch = db.batch();
  const results: Array<{ id: string; name: string; amount: number; currencyCode: string; category: string; period: string; nextBillingDate: Date }> = [];

  items.forEach((template) => {
    const currencyCode = random() > 0.7 ? "USD" : random() > 0.5 ? "EUR" : "BRL";
    const amount = currencyCode === "USD" ? 12 + Math.round(random() * 30) : 20 + Math.round(random() * 150);
    const day = 5 + Math.floor(random() * 22);
    const nextBillingDate = new Date(Date.UTC(options.now.getUTCFullYear(), options.now.getUTCMonth(), day));
    const ref = subscriptionsRef.doc();
    batch.set(ref, {
      name: template.name,
      amount,
      currencyCode,
      category: template.category,
      period: template.period,
      nextBillingDate: Timestamp.fromDate(nextBillingDate),
      ownerId: options.userId,
      createdAt: FieldValue.serverTimestamp()
    });
    results.push({
      id: ref.id,
      name: template.name,
      amount,
      currencyCode,
      category: template.category,
      period: template.period,
      nextBillingDate
    });
  });

  await batch.commit();
  return results;
};

const createGroups = async (
  db: FirebaseFirestore.Firestore,
  options: SeedOptions,
  random: () => number,
  subscriptions: Array<{ id: string; name: string; amount: number; currencyCode: string; category: string; period: string; nextBillingDate: Date }>
) => {
  const batch = db.batch();
  const groupDocs: Array<{ id: string; data: any; members: any[] }> = [];
  const groupsToCreate = 3 + Math.floor(random() * 2);

  for (let index = 0; index < groupsToCreate; index += 1) {
    const template = randomItem(groupTemplates, random);
    const subscription = randomItem(subscriptions, random);
    const groupRef = db.collection("groups").doc();
    const memberCount = 2 + Math.floor(random() * 3);
    const memberAmount = Math.round((subscription.amount / memberCount) * 100) / 100;
    const members: any[] = [];

    for (let memberIndex = 0; memberIndex < memberCount; memberIndex += 1) {
      const isOwner = memberIndex === 0;
      members.push({
        id: `m-${groupRef.id}-${memberIndex}`,
        name: isOwner ? "Você" : memberNames[(index + memberIndex) % memberNames.length],
        amount: memberAmount,
        status: isOwner ? "paid" : random() > 0.5 ? "pending" : "paid",
        userId: isOwner ? options.userId : null,
        photoURL: isOwner ? null : `https://i.pravatar.cc/150?img=${(index + memberIndex) % 50 + 1}`,
        receiptURL: null
      });
    }

    const memberIds = members.map((member) => member.userId).filter(Boolean);
    const groupData = {
      name: template.name,
      category: template.category,
      totalAmount: subscription.amount,
      currencyCode: subscription.currencyCode,
      billingPeriod: subscription.period === "yearly" ? "Anual" : "Mensal",
      billingDay: options.now.getUTCDate(),
      ownerId: options.userId,
      ownerPhoneNumber: "+55 31 99999-0000",
      memberIds: memberIds,
      membersPreview: members,
      subscriptionId: subscription.id,
      subscriptionName: subscription.name,
      subscriptionCategory: subscription.category,
      subscriptionPeriod: subscription.period,
      subscriptionNextBillingDate: Timestamp.fromDate(subscription.nextBillingDate),
      chargeDay: options.now.getUTCDate(),
      chargeNextBillingDate: Timestamp.fromDate(subscription.nextBillingDate),
      serviceLogin: "usuario@exemplo.com",
      servicePassword: "senha123",
      pixKey: "chavepix@exemplo.com",
      createdAt: FieldValue.serverTimestamp()
    };

    batch.set(groupRef, groupData);
    groupDocs.push({ id: groupRef.id, data: groupData, members });
  }

  await batch.commit();

  for (const group of groupDocs) {
    const membersRef = db.collection("groups").doc(group.id).collection("members");
    const membersBatch = db.batch();
    group.members.forEach((member) => {
      membersBatch.set(membersRef.doc(member.id), {
        name: member.name,
        userId: member.userId,
        status: member.status,
        amount: member.amount,
        photoURL: member.photoURL,
        receiptURL: null,
        role: member.userId === options.userId ? "owner" : "member",
        createdAt: FieldValue.serverTimestamp()
      });
    });
    await membersBatch.commit();
  }
};

const createBillingHistory = async (
  db: FirebaseFirestore.Firestore,
  options: SeedOptions,
  random: () => number,
  subscriptions: Array<{ name: string; amount: number; currencyCode: string }>
) => {
  const historyRef = db.collection("users").doc(options.userId).collection("billingHistory");
  const monthStarts = buildMonthStarts(options.months, options.now);
  const batch = db.batch();

  monthStarts.forEach((monthStart) => {
    const entries = 4 + Math.floor(random() * 4);
    for (let idx = 0; idx < entries; idx += 1) {
      const subscription = randomItem(subscriptions, random);
      const dayOffset = 1 + Math.floor(random() * 25);
      const occurredAt = new Date(Date.UTC(monthStart.getUTCFullYear(), monthStart.getUTCMonth(), dayOffset));
      const isGroup = random() > 0.7;
      const ref = historyRef.doc();
      batch.set(ref, {
        title: isGroup ? `Grupo ${subscription.name}` : subscription.name,
        amount: subscription.amount,
        currencyCode: subscription.currencyCode,
        occurredAt: Timestamp.fromDate(occurredAt),
        type: isGroup ? "group" : "subscription",
        createdAt: FieldValue.serverTimestamp()
      });
    }
  });

  await batch.commit();
};

export const seedEmulatorData = onRequest(async (req, res) => {
  if (!isEmulator()) {
    res.status(403).json({ error: "Seed allowed only in emulator." });
    return;
  }

  const options = parseOptions(req);
  if (!options.userId) {
    res.status(400).json({ error: "Missing userId." });
    return;
  }

  const db = admin.firestore();
  const random = makeRandom(options.userId.split("").reduce((sum, char) => sum + char.charCodeAt(0), 0));

  if (options.reset) {
    await ensureReset(db, options.userId);
  }

  const subscriptions = await createSubscriptions(db, options, random);
  await createGroups(db, options, random, subscriptions);
  await createBillingHistory(db, options, random, subscriptions);

  res.json({
    ok: true,
    userId: options.userId,
    months: options.months,
    subscriptions: subscriptions.length
  });
});
