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

// ---- GPS ----
export { recordTrackingPoint } from "./functions/recordTrackingPoint";

// ---- Finance ----
export { recordTip } from "./functions/recordTip";
export { createFinancialSnapshot } from "./functions/createFinancialSnapshot";
export { createLedgerEntry } from "./functions/createLedgerEntry";
export { calculateDriverPayout } from "./functions/calculateDriverPayout";

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
