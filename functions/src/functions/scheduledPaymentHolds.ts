// -----------------------------------------------------------------------------
// scheduledPaymentHolds — tâche planifiée (toutes les heures) qui pose le
// blocage du solde 4 jours avant le ramassage des réservations lointaines
// (lib/scheduledPaymentHold.ts, décision Daniel 2026-11-06).
// -----------------------------------------------------------------------------
import { onSchedule } from "firebase-functions/v2/scheduler";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { processScheduledPaymentHolds } from "../lib/scheduledPaymentHold";

export const placeScheduledPaymentHolds = onSchedule(
  { schedule: "every 60 minutes", timeZone: "America/Toronto", secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async () => {
    const result = await processScheduledPaymentHolds();
    if (result.errors > 0 || result.cancelled > 0 || result.retried > 0) {
      console.error("[scheduled-hold] attention requise", result);
    } else if (result.examined > 0) {
      console.log("[scheduled-hold]", result);
    }
  }
);
