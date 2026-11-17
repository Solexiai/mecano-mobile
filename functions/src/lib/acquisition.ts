// -----------------------------------------------------------------------------
// acquisition.ts — d'où vient chaque prospect (décision Daniel, 2026-11-17).
// Fonctions pures, testées en unitaire.
//
// À sa première visite, le site note l'adresse d'arrivée (paramètres utm_*,
// gclid, fbclid) et le site d'où vient la personne. Le serveur range cette
// première visite dans un canal lisible : publicité Facebook, publicité
// Google, recherche Google, réseaux sociaux, courriel, autre site, direct.
// -----------------------------------------------------------------------------

export type AcquisitionChannel =
  | "paid_social" | "paid_search" | "organic_search" | "organic_social"
  | "email" | "campaign" | "referral" | "direct" | "app";

export const ACQUISITION_CHANNELS: AcquisitionChannel[] = [
  "paid_social", "paid_search", "organic_search", "organic_social", "email", "campaign", "referral", "direct", "app",
];

export interface AcquisitionSource {
  channel: AcquisitionChannel;
  source: string;
  medium: string;
  campaign: string;
  content: string;
  term: string;
  referrer_host: string;
  landing_path: string;
  click_id: "gclid" | "fbclid" | "msclkid" | "";
  platform: string;
  first_seen_at_ms: number | null;
}

const SOCIAL = ["facebook", "instagram", "fb", "ig", "meta", "tiktok", "linkedin", "lnkd", "youtube", "pinterest", "twitter", "x.com", "t.co", "messenger"];
const SEARCH = ["google", "bing", "duckduckgo", "yahoo", "ecosia", "brave", "qwant"];
const PAID_MEDIUMS = ["cpc", "ppc", "paid", "paidsocial", "paid_social", "paid-social", "ads", "ad", "cpm", "display"];

function clean(value: unknown, max = 100): string {
  if (typeof value !== "string") return "";
  // Lettres, chiffres et ponctuation courante seulement ; jamais de balises.
  return value.replace(/[^\p{L}\p{N} ._~:/@+\-|]/gu, "").trim().slice(0, max);
}

function host(value: unknown): string {
  const raw = clean(value, 200).toLowerCase();
  if (!raw) return "";
  const withoutScheme = raw.replace(/^[a-z]+:\/\//, "");
  return withoutScheme.split("/")[0].replace(/^www\./, "").slice(0, 100);
}

/** Le nom (facebook, google…) est-il un des morceaux de la valeur ? « l.facebook.com » oui, « digital » non. */
function matches(value: string, list: string[]): boolean {
  const tokens = value.split(/[^a-z0-9]+/).filter((t) => t);
  return list.some((name) => (name.includes(".") ? value === name || value.endsWith(`.${name}`) : tokens.includes(name)));
}

/** Range une première visite dans un canal. Les champs inconnus sont ignorés. */
export function classifyAcquisition(raw: unknown): AcquisitionSource {
  const data = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const medium = clean(data.medium).toLowerCase();
  const referrer = host(data.referrer);
  const ownSite = referrer === "movi-k.com" || referrer.endsWith(".movi-k.com");
  const clickId = data.clickId === "gclid" || data.clickId === "fbclid" || data.clickId === "msclkid" ? data.clickId : "";
  // Un clic venu de Facebook ou de Google sans paramètre utm garde au moins le nom du réseau.
  const source = clean(data.source).toLowerCase() ||
    (clickId === "fbclid" ? "facebook" : clickId === "gclid" ? "google" : clickId === "msclkid" ? "bing" : "");
  const platform = clean(data.platform, 20).toLowerCase() || "web";
  const paid = PAID_MEDIUMS.includes(medium);
  const seen = typeof data.firstSeenAtMs === "number" && Number.isFinite(data.firstSeenAtMs) ? data.firstSeenAtMs : null;

  let channel: AcquisitionChannel;
  // gclid / msclkid n'existent que sur un clic de publicité ; fbclid est posé
  // sur TOUT lien Facebook (publicité ou publication) : payant seulement si
  // l'annonce le dit (utm_medium=cpc, paid…).
  if (clickId === "gclid" || clickId === "msclkid") channel = "paid_search";
  else if (source && matches(source, SOCIAL)) channel = paid ? "paid_social" : "organic_social";
  else if (source && matches(source, SEARCH)) channel = paid ? "paid_search" : "organic_search";
  else if (medium === "email" || source === "movik") channel = "email";
  else if (source) channel = "campaign";
  else if (referrer && !ownSite && matches(referrer, SEARCH)) channel = "organic_search";
  else if (referrer && !ownSite && matches(referrer, SOCIAL)) channel = "organic_social";
  else if (referrer && !ownSite) channel = "referral";
  else channel = platform === "web" ? "direct" : "app";

  return {
    channel,
    source,
    medium,
    campaign: clean(data.campaign),
    content: clean(data.content),
    term: clean(data.term),
    referrer_host: ownSite ? "" : referrer,
    landing_path: clean(data.landingPath, 200),
    click_id: clickId,
    platform,
    first_seen_at_ms: seen,
  };
}

/** Libellé court d'une source, pour le tableau Admin : « facebook / cpc / campagne ». */
export function acquisitionLabel(a: Pick<AcquisitionSource, "source" | "medium" | "campaign" | "referrer_host">): string {
  const parts = [a.source || a.referrer_host, a.medium, a.campaign].filter((p) => p);
  return parts.join(" / ");
}

export interface AcquisitionReportRow {
  channel: AcquisitionChannel | "unknown";
  label: string;
  accounts: number;
  priced: number;
  booked: number;
  drivers: number;
}

/**
 * Tableau « source → prix → réservation ». `accounts` : comptes dont la
 * source a été notée dans la période ; `priced` / `booked` : clients ayant
 * demandé un prix / réservé dans la période ; `drivers` : comptes de la
 * période qui ont un dossier chauffeur. Les clients sans source notée
 * (inscrits avant le suivi) vont dans « unknown ».
 */
export function buildAcquisitionReport(params: {
  sources: Map<string, AcquisitionSource>;
  newAccountIds: string[];
  pricedCustomerIds: string[];
  bookedCustomerIds: string[];
  driverIds: string[];
}): AcquisitionReportRow[] {
  const rows = new Map<string, AcquisitionReportRow>();
  const rowFor = (uid: string): AcquisitionReportRow => {
    const a = params.sources.get(uid);
    const channel = a?.channel ?? "unknown";
    const label = a ? acquisitionLabel(a) : "";
    const key = `${channel}|${label}`;
    let row = rows.get(key);
    if (!row) {
      row = { channel, label, accounts: 0, priced: 0, booked: 0, drivers: 0 };
      rows.set(key, row);
    }
    return row;
  };
  for (const uid of new Set(params.newAccountIds)) rowFor(uid).accounts += 1;
  for (const uid of new Set(params.pricedCustomerIds)) rowFor(uid).priced += 1;
  for (const uid of new Set(params.bookedCustomerIds)) rowFor(uid).booked += 1;
  for (const uid of new Set(params.driverIds)) rowFor(uid).drivers += 1;
  return [...rows.values()].sort((a, b) =>
    b.booked - a.booked || b.priced - a.priced || b.accounts - a.accounts || a.label.localeCompare(b.label));
}
