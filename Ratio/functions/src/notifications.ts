import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

const runBillingReminders = async () => {
  const db = admin.firestore();
  const now = new Date();
  const inTwoDays = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
  const maxDate = Timestamp.fromDate(inTwoDays);

  const usersSnapshot = await db.collection("users").get();
  for (const userDoc of usersSnapshot.docs) {
    const tokens: string[] = userDoc.data().fcmTokens || [];
    if (tokens.length === 0) {
      continue;
    }

    const subsSnapshot = await db
      .collection("users")
      .doc(userDoc.id)
      .collection("subscriptions")
      .where("nextBillingDate", "<=", maxDate)
      .get();

    for (const sub of subsSnapshot.docs) {
      const data = sub.data();
      const name = data.name || "Assinatura";
      const message = {
        notification: {
          title: "Cobranca em breve",
          body: `Sua assinatura de ${name} vence em breve.`
        },
        tokens
      };
      await admin.messaging().sendEachForMulticast(message);
    }
  }
};

export const sendBillingReminders = onSchedule(
  { schedule: "every 1 minutes", timeZone: "America/Sao_Paulo" },
  async () => {
    await runBillingReminders();
  }
);

export const sendBillingRemindersTest = onRequest(async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(403).send("Apenas no emulator.");
    return;
  }
  await runBillingReminders();
  res.status(200).send("OK");
});
