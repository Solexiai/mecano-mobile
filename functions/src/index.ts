// -----------------------------------------------------------------------------
// Point d'entrée Cloud Functions — Movi-K.
//
// Ré-exporte toutes les fonctions individuelles (une fonction = un fichier
// dans src/functions/) pour que Firebase les découvre au déploiement/à
// l'émulation. Aucune logique métier ici — uniquement des ré-exports.
//
// Application Default Credentials uniquement — voir src/lib/admin.ts.
// -----------------------------------------------------------------------------

// ---- Onboarding / documents chauffeur ----
export { approveDriver } from "./functions/approveDriver";
export { rejectDriver } from "./functions/rejectDriver";
export { validateDriverDocument } from "./functions/validateDriverDocument";
export { requestDriverDocuments } from "./functions/requestDriverDocuments";
export { suspendDriver } from "./functions/suspendDriver";
export { reactivateDriver } from "./functions/reactivateDriver";
export { addDriverInternalNote } from "./functions/addDriverInternalNote";
export { logDriverReviewOpened } from "./functions/logDriverReviewOpened";

// ---- Devis, missions, dispatch, acceptation ----
export { calculateDeliveryQuote } from "./functions/calculateDeliveryQuote";
export { createDeliveryRequest } from "./functions/createDeliveryRequest";
export { acceptDelivery } from "./functions/acceptDelivery";
export { completePickup } from "./functions/completePickup";
export { completeDelivery } from "./functions/completeDelivery";
export { updateMissionTrackingStatus } from "./functions/updateMissionTrackingStatus";
export { onMissionCreatedDispatch, onMissionReopenedDispatch } from "./functions/dispatchMissionToDrivers";
export { onMissionEndedClearTracking } from "./functions/onMissionEndedClearTracking";
export { onMissionStatusChangeNotifyCustomer } from "./functions/onMissionStatusChangeNotifyCustomer";

// ---- GPS ----
export { recordTrackingPoint } from "./functions/recordTrackingPoint";

// ---- Finance ----
export { recordTip } from "./functions/recordTip";
export { createFinancialSnapshot } from "./functions/createFinancialSnapshot";
export { createLedgerEntry } from "./functions/createLedgerEntry";
export { calculateDriverPayout } from "./functions/calculateDriverPayout";

// ---- Paiements (Phase 6 — infrastructure financière réelle) ----
export { createCustomerPaymentProfile } from "./functions/createCustomerPaymentProfile";
export { attachCustomerPaymentMethod } from "./functions/attachCustomerPaymentMethod";
export { createDriverStripeAccount } from "./functions/createDriverStripeAccount";
export { updatePayoutPolicyConfiguration } from "./functions/updatePayoutPolicyConfiguration";
export { processScheduledDriverPayouts } from "./functions/processScheduledDriverPayouts";
export { refundPayment } from "./functions/refundPayment";
export { updateDisputeStatus } from "./functions/updateDisputeStatus";
export { processStripeWebhook } from "./functions/processStripeWebhook";

// ---- Taxes (Phase 6, bloc E — moteur de taxes configurable) ----
export { updateTaxConfiguration } from "./functions/updateTaxConfiguration";

// ---- Commission / promotions / Founding Driver / pricing ----
export { applyDriverPromotion } from "./functions/applyDriverPromotion";
export { qualifyFoundingDriver, revokeFoundingDriverStatus } from "./functions/qualifyFoundingDriver";
export { updatePricingConfiguration } from "./functions/updatePricingConfiguration";

// ---- Rôles (Custom Claims) ----
export { setUserRole } from "./functions/setUserRole";
export { registerAsDriver } from "./functions/registerAsDriver";
export { submitDriverForReview } from "./functions/submitDriverForReview";

// ---- Cron / fonctions planifiées ----
export { detectExpiringDocuments } from "./functions/detectExpiringDocuments";
export { expireDriverPromotions } from "./functions/expireDriverPromotions";
export { transitionFoundingDriverPeriods } from "./functions/transitionFoundingDriverPeriods";
export { cleanupExpiredTrackingHistory } from "./functions/cleanupExpiredTrackingHistory";
