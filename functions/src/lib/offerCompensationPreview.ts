// -----------------------------------------------------------------------------
// offerCompensationPreview — montant que le chauffeur GAGNERAIT s'il accepte,
// calculé AU MOMENT DE L'OFFRE (2026-11-09, Daniel : « le chauffeur ne voit
// pas le montant qu'il peut recevoir »).
//
// Avant : `driver_offer_amount` de la mission restait à 0 jusqu'à
// l'acceptation (la part dépend du chauffeur : commission standard, promo ou
// Founding Driver). La carte d'offre affichait « Voir l'offre » et la
// notification ne disait rien du montant. Uber montre le montant d'abord.
//
// Ici : pour chaque chauffeur à qui on fait une offre, on réutilise EXACTEMENT
// le calcul de l'acceptation (`readDriverOfferCompensation`) en lecture seule,
// et on écrit le résultat sur l'OFFRE (`delivery_offers.driver_offer_amount`)
// et dans le push. La mission n'est pas touchée : à l'acceptation, le calcul
// est refait et fait foi (si la commission du chauffeur a changé entre-temps,
// l'app affiche le montant exact avant la confirmation finale, comme avant).
//
// FAIL-SOFT : toute erreur (devis introuvable, version de prix manquante…)
// donne « montant inconnu » pour ce chauffeur — l'offre part quand même, la
// carte retombe sur « Voir l'offre ». Un dispatch ne doit JAMAIS échouer pour
// une prévisualisation.
//
// Transactions Firestore : toutes les lectures doivent précéder les
// écritures. Appeler ce helper AVANT le premier `tx.set` du dispatch.
// -----------------------------------------------------------------------------

import { db } from "./admin";
import { readDriverOfferCompensation } from "./driverOfferCompensation";
import { toMinorUnits } from "./money";
import { resolveLockedQuote } from "./quoteIntegrity";
import { DeliveryMissionDoc } from "./types";

export interface OfferCompensationPreview {
  /** Part du chauffeur en cents (CAD). */
  driver_offer_minor: number;
  /** Part du chauffeur en dollars, pour affichage. */
  driver_offer_amount: number;
}

/** `null` pour un chauffeur dont le montant n'a pas pu être calculé. */
export async function previewOfferCompensations(
  tx: FirebaseFirestore.Transaction,
  mission: Pick<DeliveryMissionDoc, "active_quote_id">,
  driverIds: string[]
): Promise<Map<string, OfferCompensationPreview | null>> {
  const result = new Map<string, OfferCompensationPreview | null>();
  for (const id of driverIds) result.set(id, null);
  if (driverIds.length === 0) return result;

  const quoteId = mission.active_quote_id;
  if (!quoteId) return result;

  let locked;
  try {
    const quoteSnap = await tx.get(db.collection("delivery_quotes").doc(quoteId));
    if (!quoteSnap.exists) return result;
    locked = resolveLockedQuote(quoteId, quoteSnap.data() as Record<string, unknown>);
  } catch {
    return result;
  }

  for (const driverId of driverIds) {
    try {
      const { compensation } = await readDriverOfferCompensation(tx, driverId, locked);
      const amount = compensation.driverOfferAmount;
      if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) continue;
      result.set(driverId, {
        driver_offer_minor: toMinorUnits(amount),
        driver_offer_amount: amount,
      });
    } catch {
      // Montant inconnu pour ce chauffeur ; l'offre part quand même.
    }
  }
  return result;
}

/** « 62,40 $ » — format court pour une notification (fr/en/es). */
export function formatOfferAmountForPush(amount: number, locale: "fr" | "en" | "es"): string {
  const fixed = amount.toFixed(2);
  if (locale === "en") return `$${fixed}`;
  return `${fixed.replace(".", ",")} $`;
}
