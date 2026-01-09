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
const chunk = (items, size) => {
    const result = [];
    for (let index = 0; index < items.length; index += size) {
        result.push(items.slice(index, index + size));
    }
    return result;
};
const runBillingReminders = async (includeDiagnostics) => {
    const db = admin.firestore();
    const now = new Date();
    const inFiveDays = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000);
    const maxDate = firestore_1.Timestamp.fromDate(inFiveDays);
    const usersSnapshot = await db.collection("users").get();
    const summary = {
        maxDateISO: inFiveDays.toISOString(),
        usersScanned: usersSnapshot.size,
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
            "2": 0,
            "5": 0
        },
        groupOffsetDebug: [],
        sends: 0,
        successCount: 0,
        failureCount: 0,
        failures: []
    };
    const timeZone = "America/Sao_Paulo";
    const startOfDayUtc = (date) => {
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
    const offsetDays = (date) => {
        const todayUtc = startOfDayUtc(now);
        const targetUtc = startOfDayUtc(date);
        return Math.round((targetUtc - todayUtc) / (24 * 60 * 60 * 1000));
    };
    const validOffsets = new Set([0, 2, 5]);
    const reminderTextForOffset = (offset) => {
        if (offset === 0) {
            return "vence hoje.";
        }
        if (offset === 2) {
            return "vence em 2 dias.";
        }
        return "vence em 5 dias.";
    };
    const sendNotification = async (title, body, tokens, route) => {
        summary.sends += 1;
        for (const tokenChunk of chunk(tokens, 500)) {
            const response = await admin.messaging().sendEachForMulticast({
                notification: { title, body },
                data: { route },
                tokens: tokenChunk
            });
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
    for (const userDoc of usersSnapshot.docs) {
        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) {
            continue;
        }
        summary.usersWithTokens += 1;
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
                if (!(nextBillingDate instanceof firestore_1.Timestamp)) {
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
            const nextBillingDate = data.nextBillingDate;
            if (!nextBillingDate) {
                continue;
            }
            const offset = offsetDays(nextBillingDate.toDate());
            if (!validOffsets.has(offset)) {
                continue;
            }
            const name = data.name || "Assinatura";
            const body = `Sua assinatura de ${name} ${reminderTextForOffset(offset)}`;
            await sendNotification("Cobranca em breve", body, tokens, "subscriptions");
            summary.remindersByOffset[String(offset)] += 1;
        }
    }
    const groupsByChargeSnapshot = await db
        .collection("groups")
        .where("chargeNextBillingDate", "<=", maxDate)
        .get();
    const groupsBySubscriptionSnapshot = await db
        .collection("groups")
        .where("subscriptionNextBillingDate", "<=", maxDate)
        .get();
    const matchedGroups = new Map();
    groupsByChargeSnapshot.docs.forEach((doc) => matchedGroups.set(doc.id, doc));
    groupsBySubscriptionSnapshot.docs.forEach((doc) => matchedGroups.set(doc.id, doc));
    summary.groupsMatched = matchedGroups.size;
    if (includeDiagnostics) {
        const allGroupsSnapshot = await db.collection("groups").get();
        summary.groupsScanned = allGroupsSnapshot.size;
        for (const groupDoc of allGroupsSnapshot.docs) {
            const data = groupDoc.data();
            const nextBillingDate = data.subscriptionNextBillingDate;
            if (!nextBillingDate) {
                summary.groupsMissingNextBillingDateCount += 1;
                continue;
            }
            if (!(nextBillingDate instanceof firestore_1.Timestamp)) {
                summary.groupsNonTimestampCount += 1;
            }
        }
    }
    for (const groupDoc of matchedGroups.values()) {
        const data = groupDoc.data();
        const groupName = data.name || "Grupo";
        const nextBillingDate = data.chargeNextBillingDate ||
            data.subscriptionNextBillingDate;
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
        if (!validOffsets.has(offset)) {
            continue;
        }
        const memberIds = data.memberIds ?? [];
        if (memberIds.length == 0) {
            continue;
        }
        const userSnapshots = await Promise.all(memberIds.map((userId) => db.collection("users").doc(userId).get()));
        const tokens = new Set();
        for (const userSnapshot of userSnapshots) {
            const userTokens = userSnapshot.data()?.fcmTokens || [];
            userTokens.forEach((token) => tokens.add(token));
        }
        if (tokens.size == 0) {
            continue;
        }
        const body = `O grupo ${groupName} ${reminderTextForOffset(offset)}`;
        await sendNotification("Cobranca em breve", body, Array.from(tokens), "groups");
        summary.remindersByOffset[String(offset)] += 1;
    }
    return summary;
};
exports.sendBillingReminders = (0, scheduler_1.onSchedule)({ schedule: "every day 09:00", timeZone: "America/Sao_Paulo" }, async () => {
    const summary = await runBillingReminders(false);
    console.log("sendBillingReminders summary", summary);
});
exports.sendBillingRemindersTest = (0, https_1.onRequest)(async (req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(403).send("Apenas no emulator.");
        return;
    }
    const summary = await runBillingReminders(true);
    res.status(200).json(summary);
});
