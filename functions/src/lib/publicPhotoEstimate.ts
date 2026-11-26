// -----------------------------------------------------------------------------
// « Pas certain ? Ajoutez une photo » sur la page d'estimation (décision du
// propriétaire, 26 novembre 2026).
//
// Le visiteur sans compte envoie une photo de son objet ; l'IA déjà utilisée
// par la demande de livraison (lib/openAiPhotoAnalyzer.ts) reconnaît l'objet,
// et la classe de cet objet dans la grille active donne le poids de
// l'estimation : léger, moyen ou lourd. La photo n'est ni enregistrée ni
// rattachée à une personne ; seul le nom de l'objet et son poids repartent.
//
// Un appel à l'IA coûte de l'argent et la fonction est ouverte à tous :
//   - la photo est réduite sur l'appareil, et refusée ici au-delà de 1,5 Mo ;
//   - plafond par adresse IP (3 photos par 10 minutes, 6 par jour) ;
//   - le plafond quotidien global de l'analyse de photos
//     (system_config/photo_analysis.globalDailyLimit) est partagé avec la
//     demande de livraison : la dépense totale ne peut pas le dépasser ;
//   - `publicEstimateEnabled: false` dans ce même document ferme cet usage
//     sans toucher à la demande de livraison.
// -----------------------------------------------------------------------------
import { PROPOSED_ITEM_CLASSES } from "./itemClassFees";
import { assertPhotoBytes, PhotoAnalysisError } from "./photoAnalysis";
import { EstimateWeight } from "./publicEstimate";
import { ItemClass, PricingVersionDoc } from "./types";

export const MAX_PUBLIC_PHOTO_BYTES = 1536 * 1024;
const MAX_BASE64_LENGTH = Math.ceil(MAX_PUBLIC_PHOTO_BYTES / 3) * 4;

export const PUBLIC_PHOTO_LIMITS = Object.freeze({
  perIpWindow: 3,
  windowMs: 10 * 60 * 1000,
  perIpPerDay: 6,
});

export interface PublicPhotoRequest {
  bytes: Buffer;
  locale: "fr" | "en" | "es";
}

/** Accord donné, langue connue, image JPEG en base64 d'une taille raisonnable. */
export function parsePublicPhotoRequest(value: unknown): PublicPhotoRequest {
  const v = value as Record<string, unknown> | null;
  if (!v || typeof v !== "object" || v.consent !== true ||
      !["fr", "en", "es"].includes(v.locale as string) ||
      typeof v.imageBase64 !== "string" || v.imageBase64.length < 8 ||
      v.imageBase64.length > MAX_BASE64_LENGTH || !/^[A-Za-z0-9+/]+={0,2}$/.test(v.imageBase64)) {
    throw new PhotoAnalysisError("invalid-argument");
  }
  const bytes = Buffer.from(v.imageBase64, "base64");
  if (bytes.length > MAX_PUBLIC_PHOTO_BYTES) throw new PhotoAnalysisError("invalid-argument");
  assertPhotoBytes(bytes);
  return { bytes, locale: v.locale as PublicPhotoRequest["locale"] };
}

export interface PublicPhotoConfig {
  model: string;
  globalDailyLimit: number;
}

/** Même document de réglages que la demande de livraison, sans liste de comptes. */
export function publicPhotoConfig(raw: Record<string, unknown> | undefined): PublicPhotoConfig {
  if (!raw || raw.enabled !== true || raw.publicEstimateEnabled === false || raw.provider !== "openai" ||
      typeof raw.model !== "string" || !/^[a-zA-Z0-9._:-]{1,100}$/.test(raw.model) ||
      !Number.isSafeInteger(raw.globalDailyLimit) || (raw.globalDailyLimit as number) < 1 ||
      (raw.globalDailyLimit as number) > 10000) {
    throw new PhotoAnalysisError("failed-precondition");
  }
  return { model: raw.model, globalDailyLimit: raw.globalDailyLimit as number };
}

// A type alias (not an interface) so a stored counter can be passed back in.
export type PublicPhotoUsage = {
  day: string;
  count: number;
  windowStartMs: number;
  windowCount: number;
};

/**
 * Le compteur de l'adresse IP après une photo de plus, ou null si un plafond
 * est atteint. Un compteur illisible est traité comme atteint.
 */
export function nextPublicPhotoUsage(
  stored: Record<string, unknown> | undefined,
  day: string,
  now: number
): PublicPhotoUsage | null {
  const s = stored ?? {};
  const valid = (n: unknown) => n === undefined || (Number.isSafeInteger(n) && (n as number) >= 0);
  if (!valid(s.count) || !valid(s.windowCount) || !valid(s.windowStartMs)) return null;
  const dayCount = s.day === day ? ((s.count as number | undefined) ?? 0) : 0;
  const windowStart = (s.windowStartMs as number | undefined) ?? 0;
  const inWindow = windowStart <= now && now - windowStart < PUBLIC_PHOTO_LIMITS.windowMs;
  const windowCount = inWindow ? ((s.windowCount as number | undefined) ?? 0) : 0;
  if (dayCount >= PUBLIC_PHOTO_LIMITS.perIpPerDay || windowCount >= PUBLIC_PHOTO_LIMITS.perIpWindow) return null;
  return {
    day,
    count: dayCount + 1,
    windowStartMs: inWindow ? windowStart : now,
    windowCount: windowCount + 1,
  };
}

/**
 * Le poids de l'estimation pour un type d'objet reconnu : la classe de cet
 * objet dans la grille active. « Très lourd » s'estime comme « lourd », le
 * choix le plus haut de la page. Null pour « autre » : l'IA n'est pas sûre,
 * le visiteur choisit lui-même.
 */
export function estimateWeightForCategory(
  config: Pick<PricingVersionDoc, "item_class_fees">,
  category: string
): EstimateWeight | null {
  if (category === "other") return null;
  const classes: Record<string, ItemClass> = config.item_class_fees?.classes ?? {};
  const itemClass = classes[category] ?? PROPOSED_ITEM_CLASSES[category] ?? "medium";
  return itemClass === "very_heavy" ? "heavy" : itemClass;
}
