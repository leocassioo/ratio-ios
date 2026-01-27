import * as admin from "firebase-admin";

admin.initializeApp();

export {
  sendBillingReminders,
  sendBillingRemindersTest,
  notifyOwnerOnPaymentSubmitted,
  notifyOwnerOnPaymentSubmittedTest,
  notifyMemberOnPaymentStatusChanged,
  notifyOwnerOnMemberJoined,
  notifyOwnerOnMemberLeft,
  markOverdueTest
} from "./notifications";

export { recordSubscriptionHistory, recordGroupPaymentHistory, recordHistoryTest } from "./history";

export { fetchUsdRateDaily, fetchUsdRateTest, fetchEurRateDaily, fetchEurRateTest } from "./exchangeRates";

export { seedEmulatorData } from "./seed";

export { cleanupUserOnDelete } from "./account";
