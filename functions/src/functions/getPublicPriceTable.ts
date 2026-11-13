// -----------------------------------------------------------------------------
// getPublicPriceTable — Cloud Function callable PUBLIQUE, LECTURE SEULE.
//
// Sert le tableau de prix approximatifs de la page Tarifs et le « à partir
// de » de l'accueil (décision du propriétaire, 13 novembre 2026). Aucune
// connexion requise, aucune donnée reçue du visiteur, rien d'écrit.
//
// Le calcul est celui du simulateur admin (quoteAmounts), donc celui du devis
// officiel, avec la grille ACTIVE. La réponse ne contient que des totaux
// client. Le résultat est gardé 10 minutes en mémoire : un visiteur ne coûte
// aucune lecture de plus, et une nouvelle grille publiée apparaît au plus
// tard 10 minutes après.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { failedPrecondition } from "../lib/errors";
import { missionFeePolicyFrom } from "../lib/missionFees";
import { PILOT_PRICING_CATEGORIES } from "../lib/pricingConfigValidation";
import {
  assemblePublicPriceTable,
  PUBLIC_PRICE_DISTANCES_KM,
  PUBLIC_PRICE_HANDLING,
  publicPriceDurationMinutes,
  PublicPriceRow,
  publicPriceRows,
  PublicPriceTable,
} from "../lib/publicPriceTable";
import { PricingVersionDoc } from "../lib/types";
import { quoteAmounts } from "./previewPricingConfiguration";

const CACHE_MS = 10 * 60 * 1000;
let cached: { table: PublicPriceTable; expiresAtMs: number } | null = null;

const UNAVAILABLE = "Les prix ne sont pas disponibles pour le moment.";

async function buildTable(): Promise<PublicPriceTable> {
  const activeSnap = await db.collection("pricing_configs").doc("active").get();
  const rawActiveId = activeSnap.data()?.active_pricing_version;
  const activeId = typeof rawActiveId === "string" && rawActiveId.trim() ? rawActiveId.trim() : null;
  if (!activeId) throw failedPrecondition(UNAVAILABLE);
  const versionSnap = await db.collection("pricing_versions").doc(activeId).get();
  const active = versionSnap.data() as PricingVersionDoc | undefined;
  if (!active) throw failedPrecondition(UNAVAILABLE);

  const feePolicy = missionFeePolicyFrom(active.mission_fee_policy, activeId);
  const atMillis = admin.firestore.Timestamp.now().toMillis();
  const rows: PublicPriceRow[] = [];
  for (const plan of publicPriceRows(active)) {
    const totals: number[] = [];
    for (const distanceKm of PUBLIC_PRICE_DISTANCES_KM) {
      const amounts = await quoteAmounts(
        active,
        PILOT_PRICING_CATEGORIES[0],
        {
          id: `${plan.item_class}_${distanceKm}`,
          distanceKm,
          durationMinutes: publicPriceDurationMinutes(distanceKm),
          additionalStops: 0,
          handling: { ...PUBLIC_PRICE_HANDLING },
          items: [{ category: plan.categories[0], quantity: 1 }],
        },
        feePolicy,
        atMillis
      );
      if (!amounts) throw failedPrecondition(UNAVAILABLE);
      totals.push(amounts.customer_total_minor);
    }
    rows.push({ ...plan, totals_minor: totals });
  }
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
