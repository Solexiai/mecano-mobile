// -----------------------------------------------------------------------------
// getPublicPriceTable — Cloud Function callable PUBLIQUE, LECTURE SEULE.
//
// Sert le tableau de prix de la page Tarifs, de l'accueil et de la
// réservation. Aucune connexion requise, aucune donnée reçue du visiteur,
// rien d'écrit.
//
// Depuis le 15 novembre 2026, les montants sont ceux de la fiche du
// propriétaire (lib/publicPriceTable.ts), pas un calcul de la grille. La
// grille active ne sert plus qu'à nommer les objets de chaque ligne. Le
// résultat est gardé 10 minutes en mémoire.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { failedPrecondition } from "../lib/errors";
import {
  assemblePublicPriceTable,
  ownerPublicTotalsMinor,
  publicPriceRows,
  PublicPriceTable,
} from "../lib/publicPriceTable";
import { PricingVersionDoc } from "../lib/types";

const CACHE_MS = 10 * 60 * 1000;
let cached: { table: PublicPriceTable; expiresAtMs: number } | null = null;

const UNAVAILABLE = "Les prix ne sont pas disponibles pour le moment.";

/** The active grid, only for the item types of each class; an unreadable
 * grid falls back to the proposed classes rather than hiding the prices. */
async function activeGrid(): Promise<Pick<PricingVersionDoc, "item_class_fees">> {
  try {
    const activeSnap = await db.collection("pricing_configs").doc("active").get();
    const rawActiveId = activeSnap.data()?.active_pricing_version;
    if (typeof rawActiveId !== "string" || !rawActiveId.trim()) return {};
    const versionSnap = await db.collection("pricing_versions").doc(rawActiveId.trim()).get();
    return (versionSnap.data() as PricingVersionDoc | undefined) ?? {};
  } catch {
    return {};
  }
}

async function buildTable(): Promise<PublicPriceTable> {
  const rows = publicPriceRows(await activeGrid()).map((plan) => ({
    ...plan,
    totals_minor: ownerPublicTotalsMinor(plan.item_class),
  }));
  const table = assemblePublicPriceTable(rows);
  if (!table) throw failedPrecondition(UNAVAILABLE);
  return table;
}

export const getPublicPriceTable = onCall(async () => {
  const now = Date.now();
  if (cached && cached.expiresAtMs > now) return cached.table;
  const table = await buildTable();
  cached = { table, expiresAtMs: now + CACHE_MS };
  return table;
});
