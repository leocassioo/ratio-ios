import * as admin from "firebase-admin";

admin.initializeApp();

export { sendBillingReminders } from "./notifications";
