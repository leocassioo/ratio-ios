import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

export const sendBillingReminders = onSchedule(
  { schedule: "every day 09:00", timeZone: "America/Sao_Paulo" },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const inTwoDays = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    const maxDate = admin.firestore.Timestamp.fromDate(inTwoDays);

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
  }
);
