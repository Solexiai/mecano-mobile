// -----------------------------------------------------------------------------
// estimateItemFromPhoto — Cloud Function callable PUBLIQUE (décision du
// propriétaire, 26 novembre 2026) : « Pas certain ? Ajoutez une photo ».
//
// Une photo → le nom de l'objet reconnu par l'IA et le poids de l'estimation
// (léger, moyen, lourd) selon la grille active. Aucune connexion requise. La
// photo n'est pas enregistrée ; seuls des compteurs d'usage sont écrits. Voir
// lib/publicPhotoEstimate.ts pour les plafonds.
// -----------------------------------------------------------------------------
import { createHash } from "crypto";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { db } from "../lib/admin";
import { analyzeWithOpenAi } from "../lib/openAiPhotoAnalyzer";
import { PhotoAnalysisError } from "../lib/photoAnalysis";
import {
  estimateWeightForCategory,
  nextPublicPhotoUsage,
  parsePublicPhotoRequest,
  publicPhotoConfig,
} from "../lib/publicPhotoEstimate";
import { EstimateWeight } from "../lib/publicEstimate";
import { activeGrid, visitorIp } from "./estimateDeliveryPrice";

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

export interface PhotoEstimateResult {
  /** Nom court de l'objet, dans la langue de la page. */
  label: string;
  category: string;
  /** Null quand l'IA n'est pas sûre : le visiteur choisit le poids. */
  weight: EstimateWeight | null;
}

export async function handleEstimateItemFromPhoto(
  request: Pick<CallableRequest<unknown>, "data" | "rawRequest">
): Promise<PhotoEstimateResult> {
  try {
    const input = parsePublicPhotoRequest(request.data);
    const config = publicPhotoConfig((await db.doc("system_config/photo_analysis").get()).data());
    const apiKey = OPENAI_API_KEY.value();
    if (!apiKey) throw new PhotoAnalysisError("failed-precondition");

    const now = Date.now();
    const day = new Date(now).toISOString().slice(0, 10);
    const ipHash = createHash("sha256").update(`public_photo:${visitorIp(request)}`).digest("hex");
    const ipRef = db.doc(`photo_analysis_usage/public_${ipHash}`);
    const globalRef = db.doc(`photo_analysis_usage/global_${day}`);
    // The attempt is counted before the provider call: a failure still
    // consumes it, so there is no free retry loop.
    await db.runTransaction(async (tx) => {
      const [ipSnap, globalSnap] = await Promise.all([tx.get(ipRef), tx.get(globalRef)]);
      const next = nextPublicPhotoUsage(ipSnap.data(), day, Date.now());
      const g = globalSnap.data() ?? {};
      const globalCount = g.count === undefined ? 0 : g.count;
      if (!next || !Number.isSafeInteger(globalCount) || globalCount < 0 ||
          globalCount >= config.globalDailyLimit) {
        throw new PhotoAnalysisError("resource-exhausted");
      }
      tx.set(ipRef, next);
      tx.set(globalRef, { day, count: globalCount + 1 });
    });

    const suggestion = await analyzeWithOpenAi({
      bytes: input.bytes, locale: input.locale, model: config.model, apiKey,
    });
    const grid = await activeGrid(Date.now());
    return {
      label: suggestion.label,
      category: suggestion.category,
      weight: estimateWeightForCategory(grid.config, suggestion.category),
    };
  } catch (e) {
    // Never leak the provider response, the key, the image or a raw exception.
    if (e instanceof PhotoAnalysisError) throw new HttpsError(e.code, "Photo analysis unavailable.");
    throw new HttpsError("unavailable", "Photo analysis unavailable.");
  }
}

export const estimateItemFromPhoto = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 60, maxInstances: 2, concurrency: 4 },
  handleEstimateItemFromPhoto
);
