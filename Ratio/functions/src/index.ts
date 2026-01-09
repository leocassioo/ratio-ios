import * as admin from "firebase-admin";

admin.initializeApp();

export { sendBillingReminders, sendBillingRemindersTest } from "./notifications";
