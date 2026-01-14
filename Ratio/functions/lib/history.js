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
exports.recordHistoryTest = exports.recordGroupPaymentHistory = exports.recordSubscriptionHistory = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
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
const dateKey = (date) => {
    const formatter = new Intl.DateTimeFormat("en-CA", {
        timeZone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit"
    });
    return formatter.format(date).replace(/-/g, "");
};
const createHistoryEntry = async (userId, id, data) => {
    const ref = admin.firestore().collection("users").doc(userId).collection("billingHistory").doc(id);
    try {
        await ref.create(data);
    }
    catch (error) {
        if (error?.code === 6) {
            return;
        }
        throw error;
    }
};
exports.recordSubscriptionHistory = (0, scheduler_1.onSchedule)({ schedule: "every day 09:10", timeZone }, async () => {
    const db = admin.firestore();
    const now = new Date();
    const startUtc = startOfDayUtc(now);
    const endUtc = startUtc + 24 * 60 * 60 * 1000 - 1;
    const startDate = firestore_1.Timestamp.fromMillis(startUtc);
    const endDate = firestore_1.Timestamp.fromMillis(endUtc);
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
            const title = data.name || "Assinatura";
            const amount = data.amount || 0;
            const currencyCode = data.currencyCode || "BRL";
            const occurredAt = data.nextBillingDate;
            const docId = `sub_${subDoc.id}_${todayKey}`;
            await createHistoryEntry(userId, docId, {
                type: "subscription",
                title,
                amount,
                currencyCode,
                occurredAt: occurredAt ?? firestore_1.Timestamp.fromDate(now),
                subscriptionId: subDoc.id,
                createdAt: firestore_1.Timestamp.fromDate(now)
            });
        }
    }
});
exports.recordGroupPaymentHistory = (0, firestore_2.onDocumentUpdated)("groups/{groupId}/members/{memberId}", async (event) => {
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
    const ownerId = groupData.ownerId;
    const memberUserId = after.userId;
    const role = after.role ?? "";
    if (!memberUserId || memberUserId === ownerId || role === "owner") {
        return;
    }
    const occurredAt = after.approvedAt ?? firestore_1.Timestamp.fromDate(new Date());
    const docId = `grp_${groupId}_${memberUserId}_${dateKey(occurredAt.toDate())}`;
    const title = groupData.name || "Grupo";
    const amount = after.amount || 0;
    const currencyCode = groupData.currencyCode || "BRL";
    await createHistoryEntry(memberUserId, docId, {
        type: "group",
        title,
        amount,
        currencyCode,
        occurredAt,
        groupId,
        memberId: event.params.memberId,
        createdAt: firestore_1.Timestamp.fromDate(new Date())
    });
});
exports.recordHistoryTest = (0, https_1.onRequest)(async (req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(403).send("Apenas no emulator.");
        return;
    }
    const userId = req.query.userId || req.body?.userId;
    const type = (req.query.type || req.body?.type || "subscription");
    const title = req.query.title || req.body?.title || "Teste";
    const amountRaw = req.query.amount || req.body?.amount || "19.90";
    const currencyCode = req.query.currencyCode || req.body?.currencyCode || "BRL";
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
        occurredAt: firestore_1.Timestamp.fromDate(now),
        createdAt: firestore_1.Timestamp.fromDate(now)
    });
    res.status(200).json({ message: "Histórico criado.", id: docId });
});
