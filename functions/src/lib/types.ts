// -----------------------------------------------------------------------------
// Types & constantes partagées — valeurs canoniques SNAKE_CASE.
//
// NOTE DE COHÉRENCE IMPORTANTE :
// `firestore.rules` et `docs/FIRESTORE_ARCHITECTURE.md` (Étapes 8-9) utilisent
// des valeurs de statut en snake_case (ex: 'registration_incomplete',
// 'searching_driver'). Ces Cloud Functions écrivent et comparent donc
// EXCLUSIVEMENT des valeurs snake_case, pour rester cohérentes avec les
// Security Rules déjà déployées.
//
// ⚠️ SUIVI CONNU (non traité dans cette étape, voir rapport final) : les
// modèles Dart actuels (`lib/backend/models/*.dart`, `lib/models/enums.dart`)
// sérialisent certains enums via `.name` (camelCase, ex: 'registrationIncomplete')
// plutôt qu'en snake_case. Cela créera un écart entre ce que Flutter écrit et
// ce que ces Cloud Functions/Security Rules attendent. Une passe de
// correction dédiée sur les enums Dart (ajout d'un getter `firestoreValue`
// snake_case) sera nécessaire avant l'intégration finale — signalé au
// rapport de l'étape 13, volontairement PAS traité ici pour respecter l'ordre
// prescrit (étape 11 = Cloud Functions uniquement).
// -----------------------------------------------------------------------------

export const PlatformRoles = {
  CUSTOMER: "customer",
  DRIVER: "driver",
  MECHANIC: "mechanic",
  ANALYST: "analyst",
  ADMIN: "admin",
  SUPER_ADMIN: "super_admin",
} as const;
export type PlatformRole = (typeof PlatformRoles)[keyof typeof PlatformRoles];

export const DriverStatuses = {
  REGISTRATION_INCOMPLETE: "registration_incomplete",
  PENDING_REVIEW: "pending_review",
  DOCUMENTS_REQUIRED: "documents_required",
  APPROVED: "approved",
  REJECTED: "rejected",
  SUSPENDED: "suspended",
  INACTIVE: "inactive",
} as const;
export type DriverStatus = (typeof DriverStatuses)[keyof typeof DriverStatuses];

export const DriverOnlineStatuses = {
  OFFLINE: "offline",
  ONLINE: "online",
  ON_MISSION: "on_mission",
} as const;
export type DriverOnlineStatus = (typeof DriverOnlineStatuses)[keyof typeof DriverOnlineStatuses];

export const DriverDocumentStatuses = {
  MISSING: "missing",
  UPLOADED: "uploaded",
  PENDING_REVIEW: "pending_review",
  APPROVED: "approved",
  REJECTED: "rejected",
  EXPIRED: "expired",
  REPLACEMENT_REQUIRED: "replacement_required",
} as const;
export type DriverDocumentStatus =
  (typeof DriverDocumentStatuses)[keyof typeof DriverDocumentStatuses];

export const MissionStatuses = {
  DRAFT: "draft",
  QUOTED: "quoted",
  SEARCHING_DRIVER: "searching_driver",
  OFFERED: "offered",
  ASSIGNED: "assigned",
  DRIVER_TO_PICKUP: "driver_to_pickup",
  ARRIVED_AT_PICKUP: "arrived_at_pickup",
  PICKED_UP: "picked_up",
  IN_TRANSIT: "in_transit",
  ARRIVED_AT_DROPOFF: "arrived_at_dropoff",
  DELIVERED: "delivered",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
  DISPUTED: "disputed",
  REFUNDED: "refunded",
  // PHASE 6 — ajout additif (aucune valeur existante modifiée) : signale au
  // client qu'une mission n'a pas pu être assignée car l'autorisation de
  // paiement a échoué (carte refusée, etc. — point 5 du cahier des charges).
  // Le client doit corriger son moyen de paiement puis peut relancer une
  // nouvelle demande (createDeliveryRequest) ; aucune reprise automatique
  // n'est faite sur CETTE mission pour rester explicite et auditable.
  PAYMENT_FAILED: "payment_failed",
} as const;
export type MissionStatus = (typeof MissionStatuses)[keyof typeof MissionStatuses];

export const OPEN_FOR_ACCEPTANCE_STATUSES: MissionStatus[] = [
  MissionStatuses.SEARCHING_DRIVER,
  MissionStatuses.OFFERED,
];

export const CommissionProgramTypes = {
  FOUNDING_PREFERRED: "founding_preferred",
  PROMOTIONAL: "promotional",
  STANDARD: "standard",
} as const;
export type CommissionProgramType =
  (typeof CommissionProgramTypes)[keyof typeof CommissionProgramTypes];

export const FoundingDriverStatuses = {
  CANDIDATE: "candidate",
  QUALIFIED: "qualified",
  SUSPENDED: "suspended",
  REVOKED: "revoked",
  EXPIRED: "expired",
} as const;
export type FoundingDriverStatus =
  (typeof FoundingDriverStatuses)[keyof typeof FoundingDriverStatuses];

export const LedgerEntryStatuses = {
  PENDING: "pending",
  CONFIRMED: "confirmed",
  REVERSED: "reversed",
  COMPENSATED: "compensated",
} as const;
export type LedgerEntryStatus = (typeof LedgerEntryStatuses)[keyof typeof LedgerEntryStatuses];

export const LedgerDirections = { CREDIT: "credit", DEBIT: "debit" } as const;
export type LedgerDirection = (typeof LedgerDirections)[keyof typeof LedgerDirections];

export const LedgerParties = {
  CUSTOMER: "customer",
  DRIVER: "driver",
  PLATFORM: "platform",
} as const;
export type LedgerParty = (typeof LedgerParties)[keyof typeof LedgerParties];

export const LedgerEntryTypes = {
  CUSTOMER_AUTHORIZATION: "customer_authorization",
  CUSTOMER_CHARGE: "customer_charge",
  CUSTOMER_SERVICE_FEE: "customer_service_fee",
  PLATFORM_COMMISSION: "platform_commission",
  DRIVER_EARNING: "driver_earning",
  DRIVER_TIP: "driver_tip",
  DRIVER_BONUS: "driver_bonus",
  TAX: "tax",
  PAYMENT_PROCESSING_FEE: "payment_processing_fee",
  PAYOUT_PROCESSING_FEE: "payout_processing_fee",
  INSURANCE_COST: "insurance_cost",
  REFUND: "refund",
  PARTIAL_REFUND: "partial_refund",
  CHARGEBACK: "chargeback",
  CHARGEBACK_REVERSAL: "chargeback_reversal",
  DRIVER_ADJUSTMENT: "driver_adjustment",
  CUSTOMER_ADJUSTMENT: "customer_adjustment",
  DRIVER_PAYOUT: "driver_payout",
  DRIVER_PAYOUT_REVERSAL: "driver_payout_reversal",
  PROMOTION_COST: "promotion_cost",
} as const;
export type LedgerEntryType = (typeof LedgerEntryTypes)[keyof typeof LedgerEntryTypes];

// -----------------------------------------------------------------------------
// PHASE 6 — Payment state machine (server-authoritative uniquement).
//
// Transitions valides (enforced dans functions/src/payment/paymentStateMachine.ts) :
//   created -> requires_payment_method -> authorization_pending -> authorized
//   authorized -> capture_pending -> captured
//   authorized -> cancelled (autorisation annulée, ex: mission annulée)
//   authorized -> failed (autorisation expirée / capture échouée)
//   captured -> partially_refunded -> refunded
//   captured -> refunded
//   captured | partially_refunded -> disputed -> chargeback
//   chargeback -> refunded (late-win / résolution) — via entrée compensatoire
// Aucune transition n'est valide depuis un état terminal (refunded, failed,
// cancelled, chargeback) sauf chargeback -> refunded (late win documenté).
// -----------------------------------------------------------------------------
export const PaymentStatuses = {
  CREATED: "created",
  REQUIRES_PAYMENT_METHOD: "requires_payment_method",
  AUTHORIZATION_PENDING: "authorization_pending",
  AUTHORIZED: "authorized",
  CAPTURE_PENDING: "capture_pending",
  CAPTURED: "captured",
  FAILED: "failed",
  CANCELLED: "cancelled",
  REFUNDED: "refunded",
  PARTIALLY_REFUNDED: "partially_refunded",
  DISPUTED: "disputed",
  CHARGEBACK: "chargeback",
} as const;
export type PaymentStatus = (typeof PaymentStatuses)[keyof typeof PaymentStatuses];

export const PayoutStatuses = {
  PENDING: "pending",
  ELIGIBLE: "eligible",
  SCHEDULED: "scheduled",
  PROCESSING: "processing",
  PAID: "paid",
  FAILED: "failed",
  REVERSED: "reversed",
  HELD: "held",
} as const;
export type PayoutStatus = (typeof PayoutStatuses)[keyof typeof PayoutStatuses];

export const DisputeStatuses = {
  OPENED: "opened",
  UNDER_REVIEW: "under_review",
  WON: "won",
  LOST: "lost",
  REVERSED: "reversed",
} as const;
export type DisputeStatus = (typeof DisputeStatuses)[keyof typeof DisputeStatuses];

export const TaxTypes = {
  GST: "gst",
  QST: "qst",
  HST: "hst",
  OTHER_TAX: "other_tax",
  TAX_EXEMPT: "tax_exempt",
} as const;
export type TaxType = (typeof TaxTypes)[keyof typeof TaxTypes];

export const RefundReasons = {
  CUSTOMER_REQUEST: "customer_request",
  CANCELLED_BEFORE_PICKUP: "cancelled_before_pickup",
  CANCELLED_AFTER_PICKUP: "cancelled_after_pickup",
  PAYMENT_ERROR: "payment_error",
  GOODWILL: "goodwill",
  ADMINISTRATIVE: "administrative",
  MISSION_IMPOSSIBLE: "mission_impossible",
  PARTIAL_DELIVERY: "partial_delivery",
  NO_SHOW: "no_show",
} as const;
export type RefundReason = (typeof RefundReasons)[keyof typeof RefundReasons];

export const WebhookProcessingStatuses = {
  RECEIVED: "received",
  PROCESSED: "processed",
  FAILED: "failed",
  IGNORED: "ignored",
} as const;
export type WebhookProcessingStatus =
  (typeof WebhookProcessingStatuses)[keyof typeof WebhookProcessingStatuses];

export const ReconciliationStatuses = {
  OK: "ok",
  ANOMALY: "anomaly",
  PENDING: "pending",
} as const;
export type ReconciliationStatus =
  (typeof ReconciliationStatuses)[keyof typeof ReconciliationStatuses];

export const FinancialSnapshotStatuses = { PENDING: "pending", CONFIRMED: "confirmed" } as const;

// -----------------------------------------------------------------------------
// Firestore document shapes (subset des champs pertinents pour les fonctions)
// -----------------------------------------------------------------------------

export interface VehiclePricingRuleDoc {
  category: string;
  base_fare: number;
  rate_per_km: number;
  rate_per_minute: number;
  minimum_charge: number;
  max_payload_kg?: number | null;
  surcharge_fixed_amount?: number | null;
}

export interface HandlingFeeConfigDoc {
  loading_fee: number;
  unloading_fee: number;
  heavy_item_fee: number;
  bulky_item_fee: number;
  stairs_fee: number;
  no_elevator_fee: number;
  second_handler_fee: number;
  special_equipment_fee: number;
}

export interface WaitingFeeConfigDoc {
  free_waiting_minutes: number;
  waiting_rate_per_minute: number;
}

export interface AdditionalStopFeeConfigDoc {
  fee_per_stop: number;
}

export interface SurchargeRuleDoc {
  id: string;
  mode: "fixed_amount" | "percentage";
  value: number;
  enabled: boolean;
}

export interface CustomerServiceFeeConfigDoc {
  service_fee_rate: number;
  minimum_service_fee: number;
}

export interface CommissionConfigDoc {
  standard_commission_rate: number;
  minimum_platform_commission: number;
  maximum_effective_commission_rate: number;
}

export interface TipPolicyConfigDoc {
  driver_tip_percentage: number;
}

export interface QuoteConfigDoc {
  quote_validity_minutes: number;
}

export interface PricingVersionDoc {
  pricing_version: string;
  is_active: boolean;
  effective_from: admin_Timestamp;
  vehicle_rules: VehiclePricingRuleDoc[];
  handling_fees: HandlingFeeConfigDoc;
  waiting_fee: WaitingFeeConfigDoc;
  additional_stop_fee: AdditionalStopFeeConfigDoc;
  surcharges: SurchargeRuleDoc[];
  customer_service_fee: CustomerServiceFeeConfigDoc;
  commission: CommissionConfigDoc;
  tip_policy: TipPolicyConfigDoc;
  quote_config: QuoteConfigDoc;
  tax_rate: number;
}

export interface DriverProfileDoc {
  uid: string;
  full_name: string;
  city: string;
  status: DriverStatus;
  service_radius_km: number;
  accepted_vehicle_categories: string[];
  accepted_item_category_keys: string[];
  rating: number;
  completed_missions: number;
  created_at: admin_Timestamp;
  approved_at?: admin_Timestamp | null;
  approved_by_user_id?: string | null;
  rejection_reason?: string | null;
  identity_verified: boolean;
  vehicle_verified: boolean;
  online_status: DriverOnlineStatus;
  current_geohash?: string | null;
  documents_all_valid: boolean;
  submitted_for_review_at?: admin_Timestamp | null;
  // Phase 2 — portail analyste (requestDriverDocuments/suspendDriver/reactivateDriver).
  documents_required_reason?: string | null;
  documents_required_at?: admin_Timestamp | null;
  documents_required_by_user_id?: string | null;
  suspended_at?: admin_Timestamp | null;
  suspended_by_user_id?: string | null;
  suspension_reason?: string | null;
  reactivated_at?: admin_Timestamp | null;
  reactivated_by_user_id?: string | null;
  // ---- PHASE 6 — Stripe Connect (compte de versement chauffeur) ----
  stripe_connected_account_id?: string | null;
  stripe_onboarding_url?: string | null;
  stripe_charges_enabled?: boolean;
  stripe_payouts_enabled?: boolean;
}

/**
 * payment_profiles/{customerId} — référence Stripe du client. AUCUNE
 * donnée de carte sensible ; uniquement l'identifiant client fournisseur et
 * la référence de moyen de paiement par défaut (jeton opaque).
 */
export interface PaymentProfileDoc {
  customer_id: string;
  provider: "stripe";
  provider_customer_id: string;
  default_payment_method_id: string | null;
  created_at: admin_Timestamp;
  updated_at: admin_Timestamp;
}

export interface DeliveryMissionDoc {
  customer_id: string;
  customer_display_name: string;
  driver_id?: string | null;
  driver_display_name?: string | null;
  status: MissionStatus;
  item_category_key: string;
  description: string;
  required_vehicle_category: string;
  pickup_address: Record<string, unknown>;
  dropoff_address: Record<string, unknown>;
  distance_km: number;
  estimated_duration_minutes: number;
  pricing_version: string;
  driver_offer_amount: number;
  customer_total: number;
  customer_discount_amount?: number;
  payment_status: PaymentStatus;
  active_quote_id?: string | null;
  active_financial_snapshot_id?: string | null;
  // PHASE 6 — référence du payments/{id} rattaché à cette mission (créé par
  // acceptDelivery(), capturé par completeDelivery()). Absent sur les
  // missions antérieures à Phase 6 (rétro-compatibilité intentionnelle,
  // voir completeDelivery.ts).
  active_payment_id?: string | null;
  created_at: admin_Timestamp;
  accepted_at?: admin_Timestamp | null;
  // Timestamps métier "statuts terrain" (Phase 5, partie 3) — un champ dédié
  // par transition, distinct de tout `updated_at` générique, pour permettre
  // de reconstituer précisément le parcours d'une mission (ETA, analytics,
  // résolution de litige) sans dépendre uniquement de `tracking_events`.
  driver_to_pickup_at?: admin_Timestamp | null;
  arrived_at_pickup_at?: admin_Timestamp | null;
  picked_up_at?: admin_Timestamp | null;
  in_transit_at?: admin_Timestamp | null;
  arrived_at_dropoff_at?: admin_Timestamp | null;
  completed_at?: admin_Timestamp | null;
  cancelled_at?: admin_Timestamp | null;
  cancellation_reason?: string | null;
  dispatch_zone_geohash: string;
  // Preuve de livraison (Phase 5, partie 3) — dénormalisée sur le document
  // mission pour un affichage client trivial (pas de lecture de
  // sous-collection nécessaire), en plus de sa trace dans `tracking_events`.
  proof_of_delivery_url?: string | null;
}

// =============================================================================
// PHASE 6 — PAIEMENTS RÉELS, COMMISSIONS, POURBOIRES, PAYOUTS, REMBOURSEMENTS
// ET RÉCONCILIATION.
//
// Toutes les valeurs monétaires des interfaces ci-dessous sont en
// UNITÉS MINEURES ENTIÈRES (cents) — jamais des nombres flottants — voir
// `functions/src/lib/money.ts`. Convention de nommage : suffixe `_minor`.
// =============================================================================

/**
 * payments/{paymentId} — le document de paiement RÉEL (autorisation/capture
 * fournisseur), distinct du `financial_snapshots` (contrat économique figé)
 * et du `transaction_ledger` (mouvements comptables). Source de vérité pour
 * l'état du paiement fournisseur.
 */
export interface PaymentDoc {
  payment_id: string;
  mission_id: string;
  customer_id: string;
  driver_id: string;
  status: PaymentStatus;
  currency: string; // 'CAD'
  amount_authorized_minor: number;
  amount_captured_minor: number;
  amount_refunded_minor: number;
  application_fee_minor: number; // commission Movi-K + frais de service, en cents
  provider: "stripe";
  provider_customer_id: string | null;
  provider_payment_method_id: string | null;
  provider_payment_intent_id: string | null;
  provider_charge_id: string | null;
  connected_account_id: string | null; // compte Stripe Connect du chauffeur
  idempotency_key: string;
  authorized_at?: admin_Timestamp | null;
  authorization_expires_at?: admin_Timestamp | null;
  captured_at?: admin_Timestamp | null;
  cancelled_at?: admin_Timestamp | null;
  failed_at?: admin_Timestamp | null;
  failure_code?: string | null;
  failure_message?: string | null;
  created_at: admin_Timestamp;
  updated_at: admin_Timestamp;
}

/**
 * driver_payouts/{payoutId} — étendu Phase 6 : hold period configurable +
 * machine d'état payout complète + référence provider.
 */
export interface DriverPayoutDoc {
  driver_id: string;
  financial_snapshot_ids: string[];
  amount_minor: number;
  currency: string;
  status: PayoutStatus;
  payout_hold_period_hours: number;
  payout_eligible_at: admin_Timestamp;
  provider_payout_id: string | null;
  connected_account_id: string | null;
  created_at: admin_Timestamp;
  scheduled_at?: admin_Timestamp | null;
  processing_at?: admin_Timestamp | null;
  paid_at?: admin_Timestamp | null;
  failed_at?: admin_Timestamp | null;
  failure_reason?: string | null;
  reversed_at?: admin_Timestamp | null;
  reversal_reason?: string | null;
  idempotency_key: string;
}

/** payout_policy_configs/default — configuration ADMIN (jamais hardcodée). */
export interface PayoutPolicyConfigDoc {
  default_hold_period_hours: number;
  new_driver_hold_period_hours: number;
  risky_driver_hold_period_hours: number;
  updated_at: admin_Timestamp;
  updated_by_user_id: string;
}

/** tax_configs/{jurisdiction} — architecture configurable, règles NON inventées. */
export interface TaxConfigDoc {
  jurisdiction: string; // ex: 'QC', 'CA', 'ON'
  tax_type: TaxType;
  rate: number; // ex: 0.05 pour GST 5%
  applies_to_transport: boolean;
  applies_to_platform_fees: boolean;
  is_active: boolean;
  tax_registration_owner: "platform" | "driver" | "not_applicable";
  updated_at: admin_Timestamp;
}

/** refunds/{refundId} — append-only, jamais modifié après création. */
export interface RefundDoc {
  refund_id: string;
  mission_id: string;
  payment_id: string;
  amount_minor: number;
  reason: RefundReason;
  initiated_by_user_id: string;
  initiated_by_role: string;
  status: "pending" | "processing" | "succeeded" | "failed";
  provider_refund_id: string | null;
  reverse_transfer: boolean;
  refund_application_fee: boolean;
  idempotency_key: string;
  created_at: admin_Timestamp;
  completed_at?: admin_Timestamp | null;
  failed_reason?: string | null;
}

/** disputes/{disputeId} — chargebacks / litiges, liés à la preuve de livraison. */
export interface DisputeDoc {
  dispute_id: string;
  mission_id: string;
  payment_id: string;
  provider_dispute_id: string;
  amount_minor: number;
  currency: string;
  reason: string;
  status: DisputeStatus;
  evidence_due_at?: admin_Timestamp | null;
  proof_of_delivery_url?: string | null; // dénormalisé depuis la mission (Phase 5)
  created_at: admin_Timestamp;
  resolved_at?: admin_Timestamp | null;
}

/** provider_webhook_events/{eventId} — idempotence + traçabilité des webhooks. */
export interface ProviderWebhookEventDoc {
  provider_event_id: string;
  event_type: string;
  received_at: admin_Timestamp;
  processed_at?: admin_Timestamp | null;
  processing_status: WebhookProcessingStatus;
  processing_attempts: number;
  last_error?: string | null;
  related_payment_id?: string | null;
  related_mission_id?: string | null;
}

/**
 * mission_financial_balance/{missionId} — vue consolidée en temps réel du
 * solde financier d'une mission (point 10 du cahier des charges). Recalculée
 * par les Cloud Functions à chaque mouvement pertinent, jamais par Flutter.
 */
export interface MissionFinancialBalanceDoc {
  mission_id: string;
  customer_amount_authorized_minor: number;
  customer_amount_captured_minor: number;
  customer_amount_refunded_minor: number;
  platform_amount_earned_minor: number;
  driver_amount_earned_minor: number;
  driver_amount_paid_minor: number;
  driver_amount_held_minor: number;
  outstanding_balance_minor: number;
  updated_at: admin_Timestamp;
}

/** reconciliation_reports/{reportId} — sorties de la fonction de réconciliation. */
export interface ReconciliationReportDoc {
  report_id: string;
  period_start: admin_Timestamp;
  period_end: admin_Timestamp;
  status: ReconciliationStatus;
  anomalies: Array<{
    type: string;
    payment_id?: string | null;
    mission_id?: string | null;
    payout_id?: string | null;
    expected_amount_minor?: number | null;
    actual_amount_minor?: number | null;
    description: string;
  }>;
  total_payments_checked: number;
  total_payouts_checked: number;
  reconciliation_difference_minor: number;
  created_at: admin_Timestamp;
  last_reconciled_at: admin_Timestamp;
}

/** idempotency_keys/{key} — verrou d'idempotence générique pour opérations critiques. */
export interface IdempotencyKeyDoc {
  key: string;
  operation: string;
  status: "in_progress" | "completed" | "failed";
  result?: Record<string, unknown> | null;
  created_at: admin_Timestamp;
  completed_at?: admin_Timestamp | null;
}

// Alias pour éviter l'import direct de firebase-admin.firestore.Timestamp
// dans chaque fichier de types (réduit le couplage).
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type admin_Timestamp = any;
