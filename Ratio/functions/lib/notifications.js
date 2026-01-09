"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendBillingRemindersTest = exports.sendBillingReminders = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const runBillingReminders = async () => {
    const db = admin.firestore();
    const now = new Date();
    const inTwoDays = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    const maxDate = firestore_1.Timestamp.fromDate(inTwoDays);
    const usersSnapshot = await db.collection("users").get();
    for (const userDoc of usersSnapshot.docs) {
        const tokens = userDoc.data().fcmTokens || [];
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
exports.sendBillingReminders = (0, scheduler_1.onSchedule)({ schedule: "every 1 minutes", timeZone: "America/Sao_Paulo" }, async () => {
    await runBillingReminders();
});
exports.sendBillingRemindersTest = (0, https_1.onRequest)(async (req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(403).send("Apenas no emulator.");
        return;
    }
    await runBillingReminders();
    res.status(200).send("OK");
});
