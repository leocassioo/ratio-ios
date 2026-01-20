import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

type ExchangeRateResult = {
  rate: number;
  asOfISO: string;
  source: string;
  marginPct: number;
};

const SOURCE = "BCB_PTAX";
const DEFAULT_MARGIN_PCT = 0.10;
type Currency = "USD" | "EUR";

const formatDateForBCB = (date: Date): string => {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const year = String(date.getFullYear());
  return `${month}-${day}-${year}`;
};

const buildBCBUrl = (currency: Currency, date: Date): string => {
  const formatted = formatDateForBCB(date);
  if (currency === "USD") {
    return `https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarDia(dataCotacao=@dataCotacao)?@dataCotacao='${formatted}'&$top=1&$format=json`;
  }
  return `https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoMoedaDia(moeda=@moeda,dataCotacao=@dataCotacao)?@moeda='EUR'&@dataCotacao='${formatted}'&$top=1&$format=json`;
};

const fetchPtaxRate = async (
  currency: Currency,
  date: Date
): Promise<{ rate: number; asOf: Date } | null> => {
  const response = await fetch(buildBCBUrl(currency, date));
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

const loadMarginPct = async (): Promise<number> => {
  try {
    const snapshot = await admin.firestore().collection("exchangeRates").doc("config").get();
    const value = snapshot.data()?.marginPct;
    const parsed = typeof value === "number" ? value : Number(value);
    if (!Number.isNaN(parsed) && parsed >= 0) {
      return parsed;
    }
  } catch {
    // ignore and fallback
  }
  return DEFAULT_MARGIN_PCT;
};

const fetchLatestPtaxRate = async (
  currency: Currency,
  marginPct: number
): Promise<ExchangeRateResult> => {
  const today = new Date();
  for (let offset = 0; offset <= 7; offset += 1) {
    const candidate = new Date(today);
    candidate.setDate(today.getDate() - offset);
    const result = await fetchPtaxRate(currency, candidate);
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

const saveRate = async (
  docId: string,
  currencyPair: string,
  data: ExchangeRateResult
): Promise<void> => {
  const db = admin.firestore();
  await db.collection("exchangeRates").doc(docId).set(
    {
      rate: data.rate,
      source: data.source,
      marginPct: data.marginPct,
      asOf: Timestamp.fromDate(new Date(data.asOfISO)),
      currencyPair,
      updatedAt: FieldValue.serverTimestamp()
    },
    { merge: true }
  );
};

const refreshUsdRate = async (marginPct: number): Promise<ExchangeRateResult> => {
  const result = await fetchLatestPtaxRate("USD", marginPct);
  await saveRate("usd", "USD_BRL", result);
  return result;
};

const refreshEurRate = async (marginPct: number): Promise<ExchangeRateResult> => {
  const result = await fetchLatestPtaxRate("EUR", marginPct);
  await saveRate("eur", "EUR_BRL", result);
  return result;
};

export const fetchUsdRateDaily = onSchedule(
  { schedule: "0 10 * * *", timeZone: "America/Sao_Paulo" },
  async () => {
    const marginPct = await loadMarginPct();
    await refreshUsdRate(marginPct);
  }
);

export const fetchEurRateDaily = onSchedule(
  { schedule: "5 10 * * *", timeZone: "America/Sao_Paulo" },
  async () => {
    const marginPct = await loadMarginPct();
    await refreshEurRate(marginPct);
  }
);

export const fetchUsdRateTest = onRequest(async (_req, res) => {
  try {
    const marginParam = _req.query.margin;
    const margin =
      typeof marginParam === "string" && marginParam.trim().length > 0
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
      const result = await fetchPtaxRate("USD", parsed);
      if (!result) {
        res.status(404).json({ error: "No PTAX data found for date." });
        return;
      }
      const payload: ExchangeRateResult = {
        rate: result.rate,
        asOfISO: result.asOf.toISOString(),
        source: SOURCE,
        marginPct
      };
      await saveRate("usd", "USD_BRL", payload);
      res.json(payload);
      return;
    }

    const result = await refreshUsdRate(marginPct);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error?.message ?? "Unknown error" });
  }
});

export const fetchEurRateTest = onRequest(async (_req, res) => {
  try {
    const marginParam = _req.query.margin;
    const margin =
      typeof marginParam === "string" && marginParam.trim().length > 0
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
      const result = await fetchPtaxRate("EUR", parsed);
      if (!result) {
        res.status(404).json({ error: "No PTAX data found for date." });
        return;
      }
      const payload: ExchangeRateResult = {
        rate: result.rate,
        asOfISO: result.asOf.toISOString(),
        source: SOURCE,
        marginPct
      };
      await saveRate("eur", "EUR_BRL", payload);
      res.json(payload);
      return;
    }

    const result = await refreshEurRate(marginPct);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error?.message ?? "Unknown error" });
  }
});
