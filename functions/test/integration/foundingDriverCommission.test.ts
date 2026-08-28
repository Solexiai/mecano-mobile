// ---------------------------------------------------------------------------
// Test d'intégration — Bloc O (Phase 6, directive 38 points) : résolution de
// commission Founding Driver / promotion / standard, EN PASSANT PAR LE VRAI
// CYCLE BACKEND (acceptDelivery -> completeDelivery -> recordTip), jamais
// pricingEngine.ts en isolation.
//
// OBJECTIF PRINCIPAL : empêcher DÉFINITIVEMENT la régression du bug corrigé
// dans acceptDelivery.ts (`foundingProgram: null` codé en dur, qui faisait
// retomber SILENCIEUSEMENT tout chauffeur Founding Driver sur le taux
// standard). Voir le commentaire "BLOC O — CORRECTIF" dans
// src/functions/acceptDelivery.ts.
//
// MÉTHODE DE CALCUL DES VALEURS ATTENDUES : on réutilise EXACTEMENT les
// mêmes fonctions que la production (`calculateCustomerQuote`,
// `resolveCommission`, `calculateDriverCompensation`,
// `calculatePlatformRevenue` — src/lib/pricingEngine.ts), avec les MÊMES
// entrées (fixtures) que celles seedées dans Firestore. On ne réimplémente
// JAMAIS une formule différente dans ce fichier (point 12 de la directive) —
// on vérifie que le VRAI backend (transaction Firestore réelle, via
// acceptDelivery.run()/completeDelivery.run()/recordTip.run()) produit
// EXACTEMENT ce que ces fonctions prédisent pour les mêmes entrées.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import { completeDelivery, CompleteDeliveryRequest } from "../../src/functions/completeDelivery";
import { recordTip, RecordTipRequest } from "../../src/functions/recordTip";
import { admin, db } from "../../src/lib/admin";
import { buildCommissionConfig, buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import {
  calculateCustomerQuote,
  calculateDriverCompensation,
  calculatePlatformRevenue,
  resolveCommission,
} from "../../src/lib/pricingEngine";
import { CommissionConfigDoc, FoundingDriverStatuses, MissionStatuses } from "../../src/lib/types";
import { toMinorUnits } from "../../src/lib/money";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

// ---------------------------------------------------------------------------
// Constantes partagées — mêmes distance/durée pour TOUS les scénarios afin
// que `mission_base_value` (donc `commissionBase`) soit identique partout et
// que seule la RÉSOLUTION DE COMMISSION varie d'un scénario à l'autre.
//
// Avec la règle cargoVan de `buildPricingConfig()` (base_fare 20,
// rate_per_km 1.5, rate_per_minute 0.3, minimum_charge 25) :
//   rawBase = 20 + 1.5*10 + 0.3*20 = 41  (> minimum_charge 25)
//   => missionBaseValue = subtotal = 41 (aucun frais annexe, aucune remise,
//      aucun service_fee, aucune taxe avec les défauts de la fixture).
// ---------------------------------------------------------------------------
const DISTANCE_KM = 10;
const DURATION_MIN = 20;

function buildDriverRequest(
  driverId: string,
  missionId: string
): CallableRequest<AcceptDeliveryRequest> {
  return {
    data: { missionId },
    auth: { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function buildCompleteRequest(
  driverId: string,
  missionId: string,
  proofUrl: string
): CallableRequest<CompleteDeliveryRequest> {
  return {
    data: { missionId, proofOfDeliveryUrl: proofUrl },
    auth: { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function buildTipRequest(
  customerId: string,
  missionId: string,
  tipAmount: number
): CallableRequest<RecordTipRequest> {
  return {
    data: { missionId, tipAmount },
    auth: { uid: customerId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedApprovedDriver(driverId: string): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    full_name: `Chauffeur ${driverId}`,
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.8,
    completed_missions: 10,
    created_at: admin.firestore.Timestamp.now(),
    approved_at: admin.firestore.Timestamp.now(),
    approved_by_user_id: "admin_seed",
    identity_verified: true,
    vehicle_verified: true,
    online_status: "online",
    documents_all_valid: true,
  });
}

async function seedPaymentProfile(customerId: string): Promise<void> {
  await db.collection("payment_profiles").doc(customerId).set(buildFakePaymentProfile(customerId));
}

async function seedPricingVersion(
  pricingVersionId: string,
  commissionOverrides: Partial<CommissionConfigDoc> = {}
): Promise<void> {
  await db
    .collection("pricing_versions")
    .doc(pricingVersionId)
    .set(buildPricingConfig({ pricing_version: pricingVersionId, commission: buildCommissionConfig(commissionOverrides) }));
}

async function seedOpenMission(params: {
  missionId: string;
  customerId: string;
  pricingVersionId: string;
}): Promise<void> {
  await db.collection("delivery_requests").doc(params.missionId).set({
    customer_id: params.customerId,
    customer_display_name: "Client Test Bloc O",
    driver_id: null,
    driver_display_name: null,
    status: "searching_driver",
    item_category_key: "furniture",
    description: "Test Bloc O — résolution de commission Founding Driver.",
    required_vehicle_category: "cargoVan",
    pickup_address: { line1: "1 rue Test", city: "Montréal" },
    dropoff_address: { line1: "2 rue Cible", city: "Laval" },
    distance_km: DISTANCE_KM,
    estimated_duration_minutes: DURATION_MIN,
    pricing_version: params.pricingVersionId,
    driver_offer_amount: 0,
    customer_total: 0,
    customer_discount_amount: 0,
    payment_status: "pending",
    active_quote_id: null,
    active_financial_snapshot_id: null,
    created_at: admin.firestore.Timestamp.now(),
    dispatch_zone_geohash: "f25dvk",
  });
}

async function seedFoundingProgram(
  programId: string,
  params: {
    isActive?: boolean;
    promotionalCommissionRate: number;
    preferredCommissionRate: number;
  }
): Promise<void> {
  await db.collection("founding_driver_programs").doc(programId).set({
    program_id: programId,
    is_active: params.isActive ?? true,
    total_slots: 100,
    slots_taken: 1,
    promotional_commission_rate: params.promotionalCommissionRate,
    promotional_duration_months: 6,
    preferred_commission_rate: params.preferredCommissionRate,
  });
}

async function seedFoundingQualification(params: {
  programParentId: string; // chemin réel founding_driver_programs/{this}/qualifications/{driverId}
  driverId: string;
  status: string;
  programId: string; // valeur du champ qual.program_id (peut différer du parent pour les tests négatifs)
  promotionalPeriodEndsAtMillis: number;
}): Promise<void> {
  await db
    .collection("founding_driver_programs")
    .doc(params.programParentId)
    .collection("qualifications")
    .doc(params.driverId)
    .set({
      driver_id: params.driverId,
      program_id: params.programId,
      status: params.status,
      qualified_at: admin.firestore.Timestamp.now(),
      promotional_period_ends_at: admin.firestore.Timestamp.fromMillis(params.promotionalPeriodEndsAtMillis),
      suspension_reason: null,
      revocation_reason: null,
      status_changed_at: admin.firestore.Timestamp.now(),
      status_changed_by_user_id: "admin_seed",
    });
}

async function seedDriverPromotion(params: {
  driverId: string;
  promotionalCommissionRate: number;
  startsAtMillis: number;
  endsAtMillis: number;
  isActive?: boolean;
}): Promise<string> {
  const ref = db.collection("driver_promotions").doc();
  await ref.set({
    driver_id: params.driverId,
    promotional_commission_rate: params.promotionalCommissionRate,
    starts_at: admin.firestore.Timestamp.fromMillis(params.startsAtMillis),
    ends_at: admin.firestore.Timestamp.fromMillis(params.endsAtMillis),
    is_active: params.isActive ?? true,
    created_by_user_id: "admin_seed",
    reason: "Test Bloc O",
  });
  return ref.id;
}

async function cleanupMissionArtifacts(missionId: string): Promise<void> {
  const [snapshots, auditLogs, events, payments, ledger] = await Promise.all([
    db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
    db.collection("audit_logs").where("target_id", "==", missionId).get(),
    db.collection("delivery_requests").doc(missionId).collection("tracking_events").get(),
    db.collection("payments").where("mission_id", "==", missionId).get(),
    db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
  ]);
  await Promise.all([
    ...snapshots.docs.map((d) => d.ref.delete()),
    ...auditLogs.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    ...payments.docs.map((d) => d.ref.delete()),
    ...ledger.docs.map((d) => d.ref.delete()),
    db.collection("delivery_requests").doc(missionId).delete(),
    db.collection("mission_financial_balance").doc(missionId).delete(),
  ]);
}

async function cleanupCommonSeed(params: {
  missionId: string;
  driverId: string;
  customerId: string;
  pricingVersionId: string;
}): Promise<void> {
  await Promise.all([
    cleanupMissionArtifacts(params.missionId),
    db.collection("driver_profiles").doc(params.driverId).delete(),
    db.collection("pricing_versions").doc(params.pricingVersionId).delete(),
    db.collection("payment_profiles").doc(params.customerId).delete(),
    db.collection("driver_locations").doc(params.driverId).delete(),
  ]);
}

async function cleanupFoundingProgram(programId: string, driverId?: string): Promise<void> {
  if (driverId) {
    await db
      .collection("founding_driver_programs")
      .doc(programId)
      .collection("qualifications")
      .doc(driverId)
      .delete();
  }
  await db.collection("founding_driver_programs").doc(programId).delete();
}

async function cleanupDriverPromotions(driverId: string): Promise<void> {
  const snap = await db.collection("driver_promotions").where("driver_id", "==", driverId).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

async function forceMissionToPickedUp(missionId: string): Promise<void> {
  await db.collection("delivery_requests").doc(missionId).update({ status: MissionStatuses.PICKED_UP });
}

async function completeAndFetchLedger(
  driverId: string,
  missionId: string
): Promise<FirebaseFirestore.QuerySnapshot> {
  await forceMissionToPickedUp(missionId);
  await completeDelivery.run(
    buildCompleteRequest(
      driverId,
      missionId,
      `https://storage.googleapis.com/movik-test/delivery_proofs/${missionId}/proof.jpg`
    )
  );
  return db.collection("transaction_ledger").where("mission_id", "==", missionId).get();
}

// ---------------------------------------------------------------------------
// Calcul des valeurs ATTENDUES en réutilisant EXACTEMENT les fonctions de
// production (jamais une formule réimplémentée ici — point 12/14).
// ---------------------------------------------------------------------------
interface ScenarioConfig {
  pricingVersionId: string;
  commissionOverrides?: Partial<CommissionConfigDoc>;
  foundingProgramId?: string;
  foundingProgramRates?: { promotionalCommissionRate: number; preferredCommissionRate: number };
  foundingQualificationStatus?: string;
  foundingPromotionalPeriodEndsAtMillis?: number;
  driverPromotion?: {
    promotionalCommissionRate: number;
    startsAtMillis: number;
    endsAtMillis: number;
    isActive?: boolean;
  };
}

function computeExpected(cfg: ScenarioConfig, nowMillis: number) {
  const commissionConfig = buildCommissionConfig(cfg.commissionOverrides ?? {});
  const pricingConfig = buildPricingConfig({
    pricing_version: cfg.pricingVersionId,
    commission: commissionConfig,
  });
  const pricingResult = calculateCustomerQuote(pricingConfig, {
    vehicleCategory: "cargoVan",
    distanceKm: DISTANCE_KM,
    estimatedDurationMinutes: DURATION_MIN,
    customerDiscountAmount: 0,
  });

  const foundingQualification = cfg.foundingProgramId
    ? {
        status: cfg.foundingQualificationStatus ?? FoundingDriverStatuses.QUALIFIED,
        promotionalPeriodEndsAtMillis: cfg.foundingPromotionalPeriodEndsAtMillis ?? nowMillis + 3_600_000,
      }
    : null;
  const foundingProgram =
    cfg.foundingProgramId &&
    cfg.foundingProgramRates &&
    foundingQualification?.status === FoundingDriverStatuses.QUALIFIED
      ? cfg.foundingProgramRates
      : null;
  const activePromotion = cfg.driverPromotion
    ? {
        promotionalCommissionRate: cfg.driverPromotion.promotionalCommissionRate,
        startsAtMillis: cfg.driverPromotion.startsAtMillis,
        endsAtMillis: cfg.driverPromotion.endsAtMillis,
        isActive: cfg.driverPromotion.isActive ?? true,
      }
    : null;

  const resolved = resolveCommission({
    nowMillis,
    foundingQualification,
    foundingProgram,
    activePromotion,
    standardRate: commissionConfig.standard_commission_rate,
  });

  const compensation = calculateDriverCompensation({
    pricingResult,
    resolvedCommission: resolved,
    commissionConfig,
  });
  const revenue = calculatePlatformRevenue({
    pricingResult,
    platformCommissionAmount: compensation.platformCommissionAmount,
  });

  return { pricingResult, resolved, compensation, revenue };
}

// ===========================================================================
// SCÉNARIOS A -> F — résolution de commission via le VRAI acceptDelivery()
// ===========================================================================

// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("Bloc O — foundingDriverCommission — Scénarios A-F (résolution réelle via acceptDelivery)", () => {
  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  // -------------------------------------------------------------------------
  // SCÉNARIO A — Standard 15% (aucun programme Founding, aucune promotion)
  // -------------------------------------------------------------------------
  describe("Scénario A — Standard 15%", () => {
    const MISSION_ID = "fc_a_mission";
    const DRIVER_ID = "fc_a_driver";
    const CUSTOMER_ID = "fc_a_customer";
    const PRICING_VERSION = "FC-A-PRICING";
    const cfg: ScenarioConfig = { pricingVersionId: PRICING_VERSION, commissionOverrides: { standard_commission_rate: 0.15 } };

    beforeEach(async () => {
      await Promise.all([
        seedApprovedDriver(DRIVER_ID),
        seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
        seedPricingVersion(PRICING_VERSION, cfg.commissionOverrides),
        seedPaymentProfile(CUSTOMER_ID),
      ]);
    });
    afterEach(async () => {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
    });

    it("applique le taux standard 15% et produit tous les montants attendus (snapshot + ledger)", async () => {
      const nowMillis = Date.now();
      const expected = computeExpected(cfg, nowMillis);

      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      expect(result.driverOfferAmount).toBeCloseTo(expected.compensation.driverOfferAmount, 5);

      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;
      expect(snapshot.commission_rate).toBeCloseTo(0.15, 8);
      expect(snapshot.commission_program).toBe("standard");
      expect(snapshot.mission_base_value).toBeCloseTo(expected.pricingResult.missionBaseValue, 5);
      expect(snapshot.driver_gross_earnings).toBeCloseTo(expected.compensation.driverGrossEarnings, 5);
      expect(snapshot.platform_commission_amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
      expect(snapshot.driver_net_mission_earnings).toBeCloseTo(expected.compensation.driverNetMissionEarnings, 5);
      expect(snapshot.driver_total_payout).toBeCloseTo(expected.compensation.driverNetMissionEarnings, 5);
      expect(snapshot.platform_gross_revenue).toBeCloseTo(expected.revenue.platformGrossRevenue, 5);
      expect(snapshot.contribution_margin).toBeCloseTo(expected.revenue.contributionMargin, 5);
      expect(snapshot.customer_total).toBeCloseTo(expected.pricingResult.customerTotal, 5);

      const ledger = await completeAndFetchLedger(DRIVER_ID, MISSION_ID);
      expect(ledger.size).toBe(5);
      const driverEarning = ledger.docs.find((d) => d.data().type === "driver_earning")!;
      expect(driverEarning.data().amount).toBeCloseTo(expected.compensation.driverOfferAmount, 5);
      const platformCommission = ledger.docs.find((d) => d.data().type === "platform_commission")!;
      expect(platformCommission.data().amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
      const customerCharge = ledger.docs.find((d) => d.data().type === "customer_charge")!;
      expect(customerCharge.data().amount).toBeCloseTo(expected.pricingResult.customerTotal, 5);
    });
  });

  // -------------------------------------------------------------------------
  // SCÉNARIO B — Programme Founding 12% (période promotionnelle active)
  // -------------------------------------------------------------------------
  describe("Scénario B — Programme Founding 12% (promotionnel)", () => {
    const MISSION_ID = "fc_b_mission";
    const DRIVER_ID = "fc_b_driver";
    const CUSTOMER_ID = "fc_b_customer";
    const PRICING_VERSION = "FC-B-PRICING";
    const PROGRAM_ID = "fc_b_program";
    const nowRef = Date.now();
    const cfg: ScenarioConfig = {
      pricingVersionId: PRICING_VERSION,
      commissionOverrides: { standard_commission_rate: 0.15 },
      foundingProgramId: PROGRAM_ID,
      foundingProgramRates: { promotionalCommissionRate: 0.12, preferredCommissionRate: 0.09 },
      foundingQualificationStatus: FoundingDriverStatuses.QUALIFIED,
      foundingPromotionalPeriodEndsAtMillis: nowRef + 3_600_000, // +1h : encore dans la période promo
    };

    beforeEach(async () => {
      await Promise.all([
        seedApprovedDriver(DRIVER_ID),
        seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
        seedPricingVersion(PRICING_VERSION, cfg.commissionOverrides),
        seedPaymentProfile(CUSTOMER_ID),
      ]);
      await seedFoundingProgram(PROGRAM_ID, cfg.foundingProgramRates!);
      await seedFoundingQualification({
        programParentId: PROGRAM_ID,
        driverId: DRIVER_ID,
        status: FoundingDriverStatuses.QUALIFIED,
        programId: PROGRAM_ID,
        promotionalPeriodEndsAtMillis: cfg.foundingPromotionalPeriodEndsAtMillis!,
      });
    });
    afterEach(async () => {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
    });

    it("applique le taux Founding promotionnel réellement configuré (12%), pas un taux inventé", async () => {
      const nowMillis = Date.now();
      const expected = computeExpected(cfg, nowMillis);
      expect(expected.resolved.rate).toBeCloseTo(0.12, 8);

      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;

      expect(snapshot.commission_rate).toBeCloseTo(0.12, 8);
      expect(snapshot.commission_program).toBe("founding_preferred");
      expect(snapshot.platform_commission_amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
      expect(snapshot.driver_gross_earnings).toBeCloseTo(expected.compensation.driverGrossEarnings, 5);
      expect(snapshot.driver_total_payout).toBeCloseTo(expected.compensation.driverNetMissionEarnings, 5);
      expect(snapshot.platform_gross_revenue).toBeCloseTo(expected.revenue.platformGrossRevenue, 5);
      expect(snapshot.contribution_margin).toBeCloseTo(expected.revenue.contributionMargin, 5);
    });
  });

  // -------------------------------------------------------------------------
  // SCÉNARIO C — Promotion chauffeur active 10% (générique, PAS Founding)
  // -------------------------------------------------------------------------
  describe("Scénario C — Promotion chauffeur active 10%", () => {
    const MISSION_ID = "fc_c_mission";
    const DRIVER_ID = "fc_c_driver";
    const CUSTOMER_ID = "fc_c_customer";
    const PRICING_VERSION = "FC-C-PRICING";
    const nowRef = Date.now();
    const cfg: ScenarioConfig = {
      pricingVersionId: PRICING_VERSION,
      commissionOverrides: { standard_commission_rate: 0.15 },
      driverPromotion: {
        promotionalCommissionRate: 0.1,
        startsAtMillis: nowRef - 3_600_000,
        endsAtMillis: nowRef + 3_600_000,
        isActive: true,
      },
    };

    beforeEach(async () => {
      await Promise.all([
        seedApprovedDriver(DRIVER_ID),
        seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
        seedPricingVersion(PRICING_VERSION, cfg.commissionOverrides),
        seedPaymentProfile(CUSTOMER_ID),
      ]);
      await seedDriverPromotion({ driverId: DRIVER_ID, ...cfg.driverPromotion! });
    });
    afterEach(async () => {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupDriverPromotions(DRIVER_ID);
    });

    it("applique la promotion active 10% avec les dates de validité respectées", async () => {
      const nowMillis = Date.now();
      const expected = computeExpected(cfg, nowMillis);
      expect(expected.resolved.rate).toBeCloseTo(0.1, 8);
      expect(expected.resolved.program).toBe("promotional");

      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;

      expect(snapshot.commission_rate).toBeCloseTo(0.1, 8);
      expect(snapshot.commission_program).toBe("promotional");
      expect(snapshot.platform_commission_amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
      expect(snapshot.driver_gross_earnings).toBeCloseTo(expected.compensation.driverGrossEarnings, 5);
      expect(snapshot.platform_gross_revenue).toBeCloseTo(expected.revenue.platformGrossRevenue, 5);
    });
  });

  // -------------------------------------------------------------------------
  // SCÉNARIO D — Founding Driver 10% PROMOTIONNEL (garde-fou anti-régression
  // du bug `foundingProgram: null` — LE scénario central de ce fichier).
  // -------------------------------------------------------------------------
  describe("Scénario D — Founding Driver 10% promotionnel (anti-régression du bug foundingProgram:null)", () => {
    const MISSION_ID = "fc_d_mission";
    const DRIVER_ID = "fc_d_driver";
    const CUSTOMER_ID = "fc_d_customer";
    const PRICING_VERSION = "FC-D-PRICING";
    const PROGRAM_ID = "fc_d_program";
    const nowRef = Date.now();
    const cfg: ScenarioConfig = {
      pricingVersionId: PRICING_VERSION,
      commissionOverrides: { standard_commission_rate: 0.15 },
      foundingProgramId: PROGRAM_ID,
      foundingProgramRates: { promotionalCommissionRate: 0.1, preferredCommissionRate: 0.08 },
      foundingQualificationStatus: FoundingDriverStatuses.QUALIFIED,
      foundingPromotionalPeriodEndsAtMillis: nowRef + 3_600_000,
    };

    beforeEach(async () => {
      await Promise.all([
        seedApprovedDriver(DRIVER_ID),
        seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
        seedPricingVersion(PRICING_VERSION, cfg.commissionOverrides),
        seedPaymentProfile(CUSTOMER_ID),
      ]);
      await seedFoundingProgram(PROGRAM_ID, cfg.foundingProgramRates!);
      await seedFoundingQualification({
        programParentId: PROGRAM_ID,
        driverId: DRIVER_ID,
        status: FoundingDriverStatuses.QUALIFIED,
        programId: PROGRAM_ID,
        promotionalPeriodEndsAtMillis: cfg.foundingPromotionalPeriodEndsAtMillis!,
      });
    });
    afterEach(async () => {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
    });

    it("un chauffeur RÉELLEMENT qualifié Founding Driver avec un VRAI program_id obtient le taux promotionnel 10% — pas le taux standard", async () => {
      const nowMillis = Date.now();
      const expected = computeExpected(cfg, nowMillis);
      expect(expected.resolved.rate).toBeCloseTo(0.1, 8);
      expect(expected.resolved.program).toBe("founding_preferred");

      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;

      // 🔒 C'EST ICI que le bug `foundingProgram: null` aurait fait échouer ce
      // test : sans la correction, commission_rate serait 0.15 (standard) et
      // commission_program serait "standard", jamais "founding_preferred".
      expect(snapshot.commission_rate).toBeCloseTo(0.1, 8);
      expect(snapshot.commission_program).toBe("founding_preferred");
      expect(snapshot.commission_rate).not.toBeCloseTo(0.15, 8);

      expect(snapshot.platform_commission_amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
      expect(snapshot.driver_gross_earnings).toBeCloseTo(expected.compensation.driverGrossEarnings, 5);
      expect(snapshot.driver_net_mission_earnings).toBeCloseTo(expected.compensation.driverNetMissionEarnings, 5);
      expect(snapshot.driver_total_payout).toBeCloseTo(expected.compensation.driverNetMissionEarnings, 5);
      expect(snapshot.platform_gross_revenue).toBeCloseTo(expected.revenue.platformGrossRevenue, 5);
      expect(snapshot.contribution_margin).toBeCloseTo(expected.revenue.contributionMargin, 5);

      const ledger = await completeAndFetchLedger(DRIVER_ID, MISSION_ID);
      expect(ledger.size).toBe(5);
      const driverEarning = ledger.docs.find((d) => d.data().type === "driver_earning")!;
      expect(driverEarning.data().amount).toBeCloseTo(expected.compensation.driverOfferAmount, 5);
      const platformCommission = ledger.docs.find((d) => d.data().type === "platform_commission")!;
      expect(platformCommission.data().amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
    });
  });

  // -------------------------------------------------------------------------
  // SCÉNARIO E — Founding preferred rate (après la période promotionnelle),
  // en utilisant le `preferred_commission_rate` RÉELLEMENT SEEDÉ (0.08, PAS
  // supposé être 10% par défaut).
  // -------------------------------------------------------------------------
  describe("Scénario E — Founding preferred rate (post-promo, taux seedé 8%)", () => {
    const MISSION_ID = "fc_e_mission";
    const DRIVER_ID = "fc_e_driver";
    const CUSTOMER_ID = "fc_e_customer";
    const PRICING_VERSION = "FC-E-PRICING";
    const PROGRAM_ID = "fc_e_program";
    const nowRef = Date.now();
    const cfg: ScenarioConfig = {
      pricingVersionId: PRICING_VERSION,
      commissionOverrides: { standard_commission_rate: 0.15 },
      foundingProgramId: PROGRAM_ID,
      // Le taux promotionnel (0.20) est délibérément DIFFÉRENT du preferred
      // (0.08), pour prouver que le resolver bascule bien sur `preferred`
      // après expiration — jamais sur le taux promotionnel résiduel.
      foundingProgramRates: { promotionalCommissionRate: 0.2, preferredCommissionRate: 0.08 },
      foundingQualificationStatus: FoundingDriverStatuses.QUALIFIED,
      foundingPromotionalPeriodEndsAtMillis: nowRef - 3_600_000, // -1h : période promo déjà TERMINÉE
    };

    beforeEach(async () => {
      await Promise.all([
        seedApprovedDriver(DRIVER_ID),
        seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
        seedPricingVersion(PRICING_VERSION, cfg.commissionOverrides),
        seedPaymentProfile(CUSTOMER_ID),
      ]);
      await seedFoundingProgram(PROGRAM_ID, cfg.foundingProgramRates!);
      await seedFoundingQualification({
        programParentId: PROGRAM_ID,
        driverId: DRIVER_ID,
        status: FoundingDriverStatuses.QUALIFIED,
        programId: PROGRAM_ID,
        promotionalPeriodEndsAtMillis: cfg.foundingPromotionalPeriodEndsAtMillis!,
      });
    });
    afterEach(async () => {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
    });

    it("après la période promotionnelle, applique le preferred_commission_rate SEEDÉ (8%), pas une valeur supposée", async () => {
      const nowMillis = Date.now();
      const expected = computeExpected(cfg, nowMillis);
      expect(expected.resolved.rate).toBeCloseTo(0.08, 8);
      expect(expected.resolved.program).toBe("founding_preferred");

      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;

      expect(snapshot.commission_rate).toBeCloseTo(0.08, 8);
      expect(snapshot.commission_rate).not.toBeCloseTo(0.2, 8); // pas le taux promo résiduel
      expect(snapshot.commission_program).toBe("founding_preferred");
      expect(snapshot.platform_commission_amount).toBeCloseTo(expected.compensation.platformCommissionAmount, 5);
      expect(snapshot.driver_gross_earnings).toBeCloseTo(expected.compensation.driverGrossEarnings, 5);
    });
  });

  // -------------------------------------------------------------------------
  // SCÉNARIO F — Promotion EXPIRÉE (générique) : le resolver retombe sur le
  // taux standard suivant la hiérarchie métier existante.
  // -------------------------------------------------------------------------
  describe("Scénario F — Promotion chauffeur expirée", () => {
    const MISSION_ID = "fc_f_mission";
    const DRIVER_ID = "fc_f_driver";
    const CUSTOMER_ID = "fc_f_customer";
    const PRICING_VERSION = "FC-F-PRICING";
    const nowRef = Date.now();
    const cfg: ScenarioConfig = {
      pricingVersionId: PRICING_VERSION,
      commissionOverrides: { standard_commission_rate: 0.15 },
      driverPromotion: {
        promotionalCommissionRate: 0.1,
        startsAtMillis: nowRef - 2 * 24 * 3_600_000, // -2 jours
        endsAtMillis: nowRef - 24 * 3_600_000, // -1 jour (déjà expirée)
        isActive: true,
      },
    };

    beforeEach(async () => {
      await Promise.all([
        seedApprovedDriver(DRIVER_ID),
        seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
        seedPricingVersion(PRICING_VERSION, cfg.commissionOverrides),
        seedPaymentProfile(CUSTOMER_ID),
      ]);
      await seedDriverPromotion({ driverId: DRIVER_ID, ...cfg.driverPromotion! });
    });
    afterEach(async () => {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupDriverPromotions(DRIVER_ID);
    });

    it("une promotion expirée n'est plus appliquée — le taux standard 15% est utilisé", async () => {
      const nowMillis = Date.now();
      const expected = computeExpected(cfg, nowMillis);
      expect(expected.resolved.rate).toBeCloseTo(0.15, 8);
      expect(expected.resolved.program).toBe("standard");

      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;

      expect(snapshot.commission_rate).toBeCloseTo(0.15, 8);
      expect(snapshot.commission_rate).not.toBeCloseTo(0.1, 8);
      expect(snapshot.commission_program).toBe("standard");
    });
  });
});

// ===========================================================================
// IMMUTABILITÉ DU SNAPSHOT — un changement de configuration globale APRÈS
// l'acceptation ne doit JAMAIS modifier un snapshot déjà créé.
// ===========================================================================
describe("Bloc O — immutabilité du financial_snapshot face à un changement de configuration ultérieur", () => {
  const MISSION_ID = "fc_immut_mission";
  const DRIVER_ID = "fc_immut_driver";
  const CUSTOMER_ID = "fc_immut_customer";
  const PRICING_VERSION = "FC-IMMUT-PRICING";
  const PROGRAM_ID = "fc_immut_program";
  const nowRef = Date.now();

  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  beforeEach(async () => {
    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
    await seedFoundingProgram(PROGRAM_ID, { promotionalCommissionRate: 0.1, preferredCommissionRate: 0.08 });
    await seedFoundingQualification({
      programParentId: PROGRAM_ID,
      driverId: DRIVER_ID,
      status: FoundingDriverStatuses.QUALIFIED,
      programId: PROGRAM_ID,
      promotionalPeriodEndsAtMillis: nowRef + 3_600_000,
    });
  });
  afterEach(async () => {
    await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
    await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
  });

  it("accepte à 10% (Founding promo), puis un changement de config globale à 50% NE modifie PAS le snapshot historique", async () => {
    const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));

    const snapshotBefore = (await db.collection("financial_snapshots").doc(result.snapshotId).get()).data()!;
    expect(snapshotBefore.commission_rate).toBeCloseTo(0.1, 8);
    const {
      commission_rate: rateBefore,
      platform_commission_amount: platformCommissionBefore,
      driver_gross_earnings: driverGrossBefore,
      driver_net_mission_earnings: driverNetBefore,
      driver_total_payout: driverPayoutBefore,
      platform_gross_revenue: grossRevenueBefore,
      contribution_margin: marginBefore,
    } = snapshotBefore;

    // ---- Changement de configuration GLOBALE après l'acceptation ----
    await db.collection("founding_driver_programs").doc(PROGRAM_ID).update({
      promotional_commission_rate: 0.5,
      preferred_commission_rate: 0.5,
    });
    await db.collection("pricing_versions").doc(PRICING_VERSION).update({
      "commission.standard_commission_rate": 0.5,
    });

    // ---- Relecture du snapshot historique — DOIT rester identique ----
    const snapshotAfter = (await db.collection("financial_snapshots").doc(result.snapshotId).get()).data()!;
    expect(snapshotAfter.commission_rate).toBe(rateBefore);
    expect(snapshotAfter.platform_commission_amount).toBe(platformCommissionBefore);
    expect(snapshotAfter.driver_gross_earnings).toBe(driverGrossBefore);
    expect(snapshotAfter.driver_net_mission_earnings).toBe(driverNetBefore);
    expect(snapshotAfter.driver_total_payout).toBe(driverPayoutBefore);
    expect(snapshotAfter.platform_gross_revenue).toBe(grossRevenueBefore);
    expect(snapshotAfter.contribution_margin).toBe(marginBefore);
    expect(snapshotAfter.commission_rate).not.toBeCloseTo(0.5, 8);
  });
});

// ===========================================================================
// TIP 100% CHAUFFEUR — le pourboire n'est jamais commissionné, ne modifie
// jamais le snapshot déjà confirmé, et va intégralement au chauffeur.
// ===========================================================================
describe("Bloc O — recordTip() : 100% chauffeur, jamais commissionné, snapshot inchangé", () => {
  const MISSION_ID = "fc_tip_mission";
  const DRIVER_ID = "fc_tip_driver";
  const CUSTOMER_ID = "fc_tip_customer";
  const PRICING_VERSION = "FC-TIP-PRICING";
  const TIP_AMOUNT = 20;

  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  beforeEach(async () => {
    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
  });
  afterEach(async () => {
    await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
  });

  it("mission acceptée -> complétée -> tip ajouté : 100% chauffeur, commission plateforme inchangée, snapshot inchangé", async () => {
    const acceptResult = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
    await forceMissionToPickedUp(MISSION_ID);
    await completeDelivery.run(
      buildCompleteRequest(
        DRIVER_ID,
        MISSION_ID,
        `https://storage.googleapis.com/movik-test/delivery_proofs/${MISSION_ID}/proof.jpg`
      )
    );

    const snapshotBefore = (await db.collection("financial_snapshots").doc(acceptResult.snapshotId).get()).data()!;
    expect(snapshotBefore.status).toBe("confirmed");
    const platformCommissionBeforeTip = snapshotBefore.platform_commission_amount;
    const platformGrossRevenueBeforeTip = snapshotBefore.platform_gross_revenue;

    await recordTip.run(buildTipRequest(CUSTOMER_ID, MISSION_ID, TIP_AMOUNT));

    // ---- Le snapshot confirmé reste TOTALEMENT inchangé (point 9/10) ----
    const snapshotAfter = (await db.collection("financial_snapshots").doc(acceptResult.snapshotId).get()).data()!;
    expect(snapshotAfter).toEqual(snapshotBefore);
    const platformCommissionAfterTip = snapshotAfter.platform_commission_amount;
    expect(platformCommissionAfterTip).toBe(platformCommissionBeforeTip); // point 9 — assertion explicite
    expect(snapshotAfter.platform_gross_revenue).toBe(platformGrossRevenueBeforeTip);

    // ---- Ledger : UNE seule entrée DRIVER_TIP, 100% du montant, PARTY=driver ----
    const tipLedger = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", MISSION_ID)
      .where("source_event", "==", "tip_added")
      .get();
    expect(tipLedger.size).toBe(1);
    const tipEntry = tipLedger.docs[0].data();
    expect(tipEntry.type).toBe("driver_tip");
    expect(tipEntry.party).toBe("driver");
    expect(tipEntry.direction).toBe("credit");
    // driver_tip_percentage par défaut de la fixture = 100 -> 100% du tip.
    expect(tipEntry.amount).toBeCloseTo(TIP_AMOUNT * 1.0, 5);

    // ---- Aucune entrée "platform" issue du tip (pas de platform_tip_fee) ----
    const allLedgerEntries = await db.collection("transaction_ledger").where("mission_id", "==", MISSION_ID).get();
    const platformEntriesFromTip = allLedgerEntries.docs.filter(
      (d) => d.data().source_event === "tip_added" && d.data().party === "platform"
    );
    expect(platformEntriesFromTip).toHaveLength(0);

    // ---- mission_financial_balance : tip comptabilisé, commission inchangée ----
    const balanceSnap = await db.collection("mission_financial_balance").doc(MISSION_ID).get();
    const balance = balanceSnap.data()!;
    expect(balance.driver_tip_minor).toBe(toMinorUnits(TIP_AMOUNT));
    expect(balance.platform_commission_minor).toBe(toMinorUnits(platformCommissionBeforeTip));
  });
});

// ===========================================================================
// NÉGATIFS FOUNDING DRIVER — corruption de configuration => refus explicite
// (fail-loud), jamais un taux inventé ni un fallback silencieux.
// ===========================================================================
describe("Bloc O — cas négatifs Founding Driver : refus explicite (fail-loud)", () => {
  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  it("qualification existante mais status='candidate' (pas 'qualified') -> PAS de taux Founding, fallback standard normal (pas d'erreur)", async () => {
    const MISSION_ID = "fc_neg_candidate_mission";
    const DRIVER_ID = "fc_neg_candidate_driver";
    const CUSTOMER_ID = "fc_neg_candidate_customer";
    const PRICING_VERSION = "FC-NEG-CANDIDATE-PRICING";
    const PROGRAM_ID = "fc_neg_candidate_program";

    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
    await seedFoundingProgram(PROGRAM_ID, { promotionalCommissionRate: 0.1, preferredCommissionRate: 0.08 });
    await seedFoundingQualification({
      programParentId: PROGRAM_ID,
      driverId: DRIVER_ID,
      status: FoundingDriverStatuses.CANDIDATE, // pas encore qualifié
      programId: PROGRAM_ID,
      promotionalPeriodEndsAtMillis: Date.now() + 3_600_000,
    });

    try {
      const result = await acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID));
      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      expect(snapshotSnap.data()!.commission_rate).toBeCloseTo(0.15, 8);
      expect(snapshotSnap.data()!.commission_program).toBe("standard");
    } finally {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
    }
  });

  it("qualification 'qualified' mais program_id manquant (vide) -> failed-precondition, AUCUNE mutation", async () => {
    const MISSION_ID = "fc_neg_noprogid_mission";
    const DRIVER_ID = "fc_neg_noprogid_driver";
    const CUSTOMER_ID = "fc_neg_noprogid_customer";
    const PRICING_VERSION = "FC-NEG-NOPROGID-PRICING";
    const PROGRAM_PARENT = "fc_neg_noprogid_parent";

    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
    await seedFoundingQualification({
      programParentId: PROGRAM_PARENT,
      driverId: DRIVER_ID,
      status: FoundingDriverStatuses.QUALIFIED,
      programId: "", // 🔒 program_id manquant/vide — corruption de configuration
      promotionalPeriodEndsAtMillis: Date.now() + 3_600_000,
    });

    try {
      await expect(acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID))).rejects.toMatchObject({
        code: "failed-precondition",
      });

      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      expect(missionSnap.data()!.status).toBe("searching_driver");
      expect(missionSnap.data()!.driver_id).toBeNull();
      const snapshots = await db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get();
      expect(snapshots.size).toBe(0);
      const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.online_status).toBe("online");
    } finally {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_PARENT, DRIVER_ID);
    }
  });

  it("qualification 'qualified' référence un founding_driver_programs INTROUVABLE -> failed-precondition", async () => {
    const MISSION_ID = "fc_neg_notfound_mission";
    const DRIVER_ID = "fc_neg_notfound_driver";
    const CUSTOMER_ID = "fc_neg_notfound_customer";
    const PRICING_VERSION = "FC-NEG-NOTFOUND-PRICING";
    const PROGRAM_PARENT = "fc_neg_notfound_parent";
    const GHOST_PROGRAM_ID = "founding_program_does_not_exist_xyz";

    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
    await seedFoundingQualification({
      programParentId: PROGRAM_PARENT,
      driverId: DRIVER_ID,
      status: FoundingDriverStatuses.QUALIFIED,
      programId: GHOST_PROGRAM_ID, // aucun founding_driver_programs/{GHOST_PROGRAM_ID} n'existe
      promotionalPeriodEndsAtMillis: Date.now() + 3_600_000,
    });

    try {
      await expect(acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID))).rejects.toMatchObject({
        code: "failed-precondition",
      });

      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      expect(missionSnap.data()!.status).toBe("searching_driver");
      const snapshots = await db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get();
      expect(snapshots.size).toBe(0);
    } finally {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_PARENT, DRIVER_ID);
    }
  });

  it("programme Founding DÉSACTIVÉ (is_active=false) -> failed-precondition", async () => {
    const MISSION_ID = "fc_neg_disabled_mission";
    const DRIVER_ID = "fc_neg_disabled_driver";
    const CUSTOMER_ID = "fc_neg_disabled_customer";
    const PRICING_VERSION = "FC-NEG-DISABLED-PRICING";
    const PROGRAM_ID = "fc_neg_disabled_program";

    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
    await seedFoundingProgram(PROGRAM_ID, {
      isActive: false, // 🔒 programme désactivé
      promotionalCommissionRate: 0.1,
      preferredCommissionRate: 0.08,
    });
    await seedFoundingQualification({
      programParentId: PROGRAM_ID,
      driverId: DRIVER_ID,
      status: FoundingDriverStatuses.QUALIFIED,
      programId: PROGRAM_ID,
      promotionalPeriodEndsAtMillis: Date.now() + 3_600_000,
    });

    try {
      await expect(acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID))).rejects.toMatchObject({
        code: "failed-precondition",
      });

      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      expect(missionSnap.data()!.status).toBe("searching_driver");
    } finally {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
    }
  });

  it("programme Founding avec taux de commission INVALIDES (non numériques) -> failed-precondition", async () => {
    const MISSION_ID = "fc_neg_badrate_mission";
    const DRIVER_ID = "fc_neg_badrate_driver";
    const CUSTOMER_ID = "fc_neg_badrate_customer";
    const PRICING_VERSION = "FC-NEG-BADRATE-PRICING";
    const PROGRAM_ID = "fc_neg_badrate_program";

    await Promise.all([
      seedApprovedDriver(DRIVER_ID),
      seedOpenMission({ missionId: MISSION_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION }),
      seedPricingVersion(PRICING_VERSION, { standard_commission_rate: 0.15 }),
      seedPaymentProfile(CUSTOMER_ID),
    ]);
    // 🔒 Écriture directe (hors helper typé) pour injecter volontairement des
    // taux invalides — jamais un chemin de code de production ne produirait
    // ceci, mais une donnée corrompue/mal migrée doit être détectée.
    await db.collection("founding_driver_programs").doc(PROGRAM_ID).set({
      program_id: PROGRAM_ID,
      is_active: true,
      total_slots: 100,
      slots_taken: 1,
      promotional_commission_rate: "dix pourcent" as unknown as number,
      promotional_duration_months: 6,
      preferred_commission_rate: null as unknown as number,
    });
    await seedFoundingQualification({
      programParentId: PROGRAM_ID,
      driverId: DRIVER_ID,
      status: FoundingDriverStatuses.QUALIFIED,
      programId: PROGRAM_ID,
      promotionalPeriodEndsAtMillis: Date.now() + 3_600_000,
    });

    try {
      await expect(acceptDelivery.run(buildDriverRequest(DRIVER_ID, MISSION_ID))).rejects.toMatchObject({
        code: "failed-precondition",
      });

      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      expect(missionSnap.data()!.status).toBe("searching_driver");
    } finally {
      await cleanupCommonSeed({ missionId: MISSION_ID, driverId: DRIVER_ID, customerId: CUSTOMER_ID, pricingVersionId: PRICING_VERSION });
      await cleanupFoundingProgram(PROGRAM_ID, DRIVER_ID);
    }
  });
});
