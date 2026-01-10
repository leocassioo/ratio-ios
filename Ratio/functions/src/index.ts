import * as admin from "firebase-admin";

admin.initializeApp();

export {
  sendBillingReminders,
  sendBillingRemindersTest,
  notifyOwnerOnPaymentSubmitted,
  notifyOwnerOnPaymentSubmittedTest
} from "./notifications";
