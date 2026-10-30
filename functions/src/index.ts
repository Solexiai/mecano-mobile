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
export { reviewDriverVehicle } from './functions/reviewDriverVehicle';
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
export { calculateRoute } from "./functions/calculateRoute";
export { createDeliveryRequest } from "./functions/createDeliveryRequest";
export { acceptDelivery } from "./functions/acceptDelivery";
export { adminAssignDelivery } from "./functions/adminAssignDelivery";
export { completePickup } from "./functions/completePickup";
export { getPaymentReceipt } from "./functions/getPaymentReceipt";
export { adminItemTypes } from "./functions/adminItemTypes";
export { adminServiceSettings } from "./functions/adminServiceSettings";
export { adminSpecialConditions } from "./functions/adminSpecialConditions";
export { adminStripeEnvironment } from "./functions/adminStripeEnvironment";
export { adminMissionActions } from "./functions/adminMissionActions";
export { completeDelivery } from "./functions/completeDelivery";
export { updateMissionTrackingStatus } from "./functions/updateMissionTrackingStatus";
export {
  onMissionCreatedDispatch,
  onMissionReopenedDispatch,
  onDriverBecameAvailableDispatch,
} from "./functions/dispatchMissionToDrivers";
export { onMissionEndedClearTracking } from "./functions/onMissionEndedClearTracking";
export { onPaymentAuthorizedAfterMissionCancel } from "./functions/onPaymentAuthorizedAfterMissionCancel";
export { recoverCancelledPendingPayments } from "./functions/recoverCancelledPendingPayments";
export { onMissionStatusChangeNotifyCustomer } from "./functions/onMissionStatusChangeNotifyCustomer";

// ---- Notifications push (Phase 8D) ----
export { registerPushToken, unregisterPushToken } from "./functions/registerPushToken";

// ---- GPS ----
export { recordTrackingPoint } from "./functions/recordTrackingPoint";

// ---- Finance ----
// 🔒 SEC-03 / PAY-02 (rapport pré-lancement 2026-10-27) — `recordTip` n'est
// PLUS exposée : elle écrivait une entrée de registre CONFIRMED (montant
// libre, sans borne) sans jamais créer de PaymentIntent ; le pourboire
// n'était ni encaissé auprès du client ni inclus dans le versement du
// chauffeur, ce qui gonflait le solde dû et déclenchait TIP_MISMATCH à la
// réconciliation. Le fichier `functions/recordTip.ts` est conservé (tests
// d'intégration du registre) jusqu'à l'implémentation d'un vrai pourboire
// Stripe. Le prochain `firebase deploy --only functions` supprimera la
// fonction déployée (confirmer la suppression lorsque la CLI le demande).
export { createFinancialSnapshot } from "./functions/createFinancialSnapshot";
// ---- Reprise de capture après livraison (PAY-03 / PAY-11, 2026-10-27) ----
export { retryFailedCaptures, retryFailedCapture, startPaymentRecoveryCardSetup } from "./functions/captureRecovery";
export { createLedgerEntry } from "./functions/createLedgerEntry";
export { calculateDriverPayout } from "./functions/calculateDriverPayout";

// ---- Paiements (Phase 6 — infrastructure financière réelle) ----
export { createCustomerPaymentProfile } from "./functions/createCustomerPaymentProfile";
export { attachCustomerPaymentMethod } from "./functions/attachCustomerPaymentMethod";
export { createDriverStripeAccount } from "./functions/createDriverStripeAccount";
export { updatePayoutPolicyConfiguration } from "./functions/updatePayoutPolicyConfiguration";
export { processScheduledDriverPayouts } from "./functions/processScheduledDriverPayouts";
// Option A (2026-10-27) : miroir, pour le chauffeur, de la part virée par
// Stripe Connect à la capture (driver_transfers/{paymentId}).
export { onPaymentWrittenMirrorDriverTransfer } from "./functions/onPaymentWrittenMirrorDriverTransfer";
// 2026-10-29 — frais Stripe réels lus après l'encaissement (bilan de mission).
export { onPaymentCapturedRecordProcessingFee, recordMissingPaymentProcessingFees } from "./functions/paymentProcessingFees";
// PAY-12 : publication des conditions de réservation finales (admin).
export { publishBookingPolicy } from "./functions/publishBookingPolicy";
export { refundPayment } from "./functions/refundPayment";
export { updateDisputeStatus } from "./functions/updateDisputeStatus";
export { processStripeWebhook, processStripeConnectWebhook } from "./functions/processStripeWebhook";

// ---- Taxes (Phase 6, bloc E — moteur de taxes configurable) ----
export { updateTaxConfiguration } from "./functions/updateTaxConfiguration";

// ---- Réconciliation (Phase 6, bloc G — moteur de réconciliation réel) ----
export { runReconciliationNow, runDailyReconciliation } from "./functions/runReconciliation";
export { resolveReconciliationAnomaly } from "./functions/resolveReconciliationAnomaly";
export { reverseDriverPayout } from "./functions/reverseDriverPayout";

// ---- Commission / promotions / Founding Driver / pricing ----
export { applyDriverPromotion } from "./functions/applyDriverPromotion";
export { qualifyFoundingDriver, revokeFoundingDriverStatus } from "./functions/qualifyFoundingDriver";
export { updatePricingConfiguration } from "./functions/updatePricingConfiguration";
export { previewPricingConfiguration } from "./functions/previewPricingConfiguration";

// ---- Rôles (Custom Claims) ----
export { setUserRole } from "./functions/setUserRole";
export { deleteDriverProfile } from "./functions/deleteDriverProfile";
export { reviewMissionFailure } from "./functions/reviewMissionFailure";
export { chargeWastedTripFee } from "./functions/chargeWastedTripFee";
// Private pilot: testers list and trial booking terms (2026-10-22).
export { adminPilotSetup } from "./functions/adminPilotSetup";
// Customer cancellation with the 2026-10-22 fee policy (lib/missionFees.ts).
export { cancelDeliveryRequest } from "./functions/cancelDeliveryRequest";
export { getAdminDriverActivity } from "./functions/getAdminDriverActivity";
export { getAdminDashboardMetrics } from "./functions/getAdminDashboardMetrics";
export { registerAsDriver } from "./functions/registerAsDriver";
export { submitDriverForReview } from "./functions/submitDriverForReview";

// ---- Cron / fonctions planifiées ----
export { detectExpiringDocuments } from "./functions/detectExpiringDocuments";
export { expireDriverPromotions } from "./functions/expireDriverPromotions";
export { transitionFoundingDriverPeriods } from "./functions/transitionFoundingDriverPeriods";
export { cleanupExpiredTrackingHistory } from "./functions/cleanupExpiredTrackingHistory";

// ---- Feature flags / kill switches (Phase 7, Bloc X) ----
export { updateRuntimeFlags } from "./functions/updateRuntimeFlags";

export { getBookingVehicleForAcceptance, requestBookingReview, getBookingQuote, getBookingConfiguration, reviewDeliveryLoad, saveBookingDraft, getBookingDraft, clearBookingDraft, cleanupBookingDrafts } from "./functions/bookingJourney";
export { startBookingCardSetup, getBookingCardStatus } from './functions/bookingCardSetup';

export { getDriverAgenda, saveDriverAgenda } from './functions/driverAgenda';

export {declineDeliveryOffer,adjustDriverMissionSlot,onMissionScheduleChanged,maintainDriverOffers,retryDriverSearch} from './functions/driverScheduleLifecycle';

export {getDriverCalendars,startDriverCalendarConnection,calendarOAuthCallback,finishDriverCalendarConnection,listDriverCalendars,selectDriverCalendars,disconnectDriverCalendar,refreshDriverCalendars,prepareDriverMissionAcceptance} from './functions/driverCalendars';
export {maintainDriverCalendars,retryDriverCalendarSync,exportDriverCalendar} from './functions/calendarSync';

export {previewDriverAvailability} from './functions/driverAgendaPreview';

export {verifyDriverServiceBase} from './functions/verifyDriverServiceBase';

// Photo suggestions only; disabled without explicit server configuration.
export { analyzeBookingPhoto } from './functions/analyzeBookingPhoto';

export { getBookingReceipt } from './functions/bookingReceipt';
