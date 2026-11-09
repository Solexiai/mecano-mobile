// -----------------------------------------------------------------------------
// tipDriver — Cloud Function callable (client, livraison terminée).
//
// Pourboire au chauffeur (décision Daniel, 2026-11-09) : 10 %, 15 %, 20 % du
// prix avant taxes ou un montant au choix (1 $ à 100 $), débité sur la carte
// enregistrée et viré à 100 % au chauffeur. Voir lib/driverTip.ts et
// payment/driverTipOrchestration.ts. Remplace l'ancien recordTip, jamais
// remis en service (registre seulement, sans encaissement).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { requireSignedIn } from "../lib/auth";
import { parseTipChoice } from "../lib/driverTip";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import { RuntimeFlagKeys, isRuntimeFlagEnabledFor, killSwitchRefusal } from "../lib/runtimeFlags";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { chargeDriverTip } from "../payment/driverTipOrchestration";

export interface TipDriverRequest {
  missionId: string;
  /** 10, 15 ou 20. */
  percent?: number;
  /** Montant au choix, en cents (100 à 10 000). */
  amountMinor?: number;
}

export const tipDriver = onCall<TipDriverRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    const missionId = request.data?.missionId;
    if (typeof missionId !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(missionId)) {
      throw invalidArgument("missionId invalide.");
    }
    const choice = parseTipChoice(request.data ?? {});
    if (!choice) {
      throw invalidArgument("Choisissez 10 %, 15 %, 20 % ou un montant entre 1 $ et 100 $.");
    }
    if (!(await isRuntimeFlagEnabledFor(RuntimeFlagKeys.PAYMENTS_ENABLED, ctx.uid))) {
      throw killSwitchRefusal();
    }
    const outcome = await chargeDriverTip({ customerId: ctx.uid, missionId, choice });
    if (!outcome.success) {
      throw failedPrecondition(
        `Votre banque a refusé le pourboire${outcome.failureMessage ? ` (${outcome.failureMessage})` : ""}. ` +
          "Aucun montant n'a été débité."
      );
    }
    return {
      success: true,
      missionId,
      paymentId: outcome.paymentId,
      amountMinor: outcome.amountMinor,
      reused: outcome.reused,
    };
  }
);
