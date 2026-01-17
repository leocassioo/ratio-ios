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
exports.fetchUsdRateTest = exports.fetchUsdRateDaily = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const SOURCE = "BCB_PTAX";
const DEFAULT_MARGIN_PCT = 0.10;
const formatDateForBCB = (date) => {
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    const year = String(date.getFullYear());
    return `${month}-${day}-${year}`;
};
const buildBCBUrl = (date) => {
    const formatted = formatDateForBCB(date);
    return `https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarDia(dataCotacao=@dataCotacao)?@dataCotacao='${formatted}'&$top=1&$format=json`;
};
const fetchPtaxRate = async (date) => {
    const response = await fetch(buildBCBUrl(date));
    if (!response.ok) {
        throw new Error(`BCB PTAX request failed: ${response.status}`);
    }
    const payload = await response.json();
    const items = Array.isArray(payload?.value) ? payload.value : [];
    if (!items.length) {
        return null;
    }
    const item = items[0];
    const rate = Number(item.cotacaoVenda);
    const asOf = item.dataHoraCotacao ? new Date(item.dataHoraCotacao) : date;
    if (!rate || Number.isNaN(rate)) {
        return null;
    }
    return { rate, asOf };
};
const loadMarginPct = async () => {
    try {
        const snapshot = await admin.firestore().collection("exchangeRates").doc("config").get();
        const value = snapshot.data()?.marginPct;
        const parsed = typeof value === "number" ? value : Number(value);
        if (!Number.isNaN(parsed) && parsed >= 0) {
            return parsed;
        }
    }
    catch {
        // ignore and fallback
    }
    return DEFAULT_MARGIN_PCT;
};
const fetchLatestPtaxRate = async (marginPct) => {
    const today = new Date();
    for (let offset = 0; offset <= 7; offset += 1) {
        const candidate = new Date(today);
        candidate.setDate(today.getDate() - offset);
        const result = await fetchPtaxRate(candidate);
        if (result) {
            return {
                rate: result.rate,
                asOfISO: result.asOf.toISOString(),
                source: SOURCE,
                marginPct
            };
        }
    }
    throw new Error("No PTAX data available in the last 7 days.");
};
const saveUsdRate = async (data) => {
    const db = admin.firestore();
    await db.collection("exchangeRates").doc("usd").set({
        rate: data.rate,
        source: data.source,
        marginPct: data.marginPct,
        asOf: firestore_1.Timestamp.fromDate(new Date(data.asOfISO)),
        currencyPair: "USD_BRL",
        updatedAt: firestore_1.FieldValue.serverTimestamp()
    }, { merge: true });
};
const refreshUsdRate = async (marginPct) => {
    const result = await fetchLatestPtaxRate(marginPct);
    await saveUsdRate(result);
    return result;
};
exports.fetchUsdRateDaily = (0, scheduler_1.onSchedule)({ schedule: "0 10 * * *", timeZone: "America/Sao_Paulo" }, async () => {
    const marginPct = await loadMarginPct();
    await refreshUsdRate(marginPct);
});
exports.fetchUsdRateTest = (0, https_1.onRequest)(async (_req, res) => {
    try {
        const marginParam = _req.query.margin;
        const margin = typeof marginParam === "string" && marginParam.trim().length > 0
            ? Number(marginParam)
            : undefined;
        const marginPct = margin !== undefined && !Number.isNaN(margin) && margin >= 0
            ? margin
            : await loadMarginPct();
        const dateParam = _req.query.date;
        if (typeof dateParam === "string" && dateParam.trim().length > 0) {
            const parsed = new Date(`${dateParam}T12:00:00Z`);
            if (Number.isNaN(parsed.getTime())) {
                res.status(400).json({ error: "Invalid date. Use YYYY-MM-DD." });
                return;
            }
            const result = await fetchPtaxRate(parsed);
            if (!result) {
                res.status(404).json({ error: "No PTAX data found for date." });
                return;
            }
            const payload = {
                rate: result.rate,
                asOfISO: result.asOf.toISOString(),
                source: SOURCE,
                marginPct
            };
            await saveUsdRate(payload);
            res.json(payload);
            return;
        }
        const result = await refreshUsdRate(marginPct);
        res.json(result);
    }
    catch (error) {
        res.status(500).json({ error: error?.message ?? "Unknown error" });
    }
});
