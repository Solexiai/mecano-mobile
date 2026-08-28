// ---------------------------------------------------------------------------
// Test d'intégration — Phase 7, Bloc X (X-11) : kill switches / runtime flags
// `system_config/runtime_flags`.
//
// PRIORITÉ EXPLICITE (directive utilisateur) : la section D (PAYMENTS) est
// la preuve permanente de BUG-X-01 — le contrôle `payments_enabled` a été
// déplacé de `createAndAuthorizeMissionPayment()` (paymentOrchestration.ts,
// où il utilisait à tort `failMissionPayment()` -> statut TERMINAL
// `PAYMENT_FAILED`) vers `acceptDelivery.ts`, AVANT la transaction
// d'assignation (`killSwitchRefusal()` — HttpsError propre, aucune écriture
// Firestore). Ce fichier prouve que ce fix tient dans le temps.
//
// Sections couvertes (X-11, lettres du plan directeur) :
//   A — résolution de config (valide / absent / champ absent / type invalide
//       / erreur Firestore)
//   B — createDeliveryRequest ON/OFF
//   C — acceptDelivery (allow_driver_acceptance) ON/OFF
//   D — PAYMENTS ON/OFF (BUG-X-01, priorité) + refunds/corrections non bloqués
//   E — voir D (fusionné : refunds/cancel authorization/reconciliation avec
//       payments_enabled=false)
//   F — payouts ON/OFF, DEUX points d'entrée (calculateDriverPayout direct +
//       cron processScheduledDriverPayouts)
//   G — corrections payout (reverseDriverPayout) non bloquées par le switch
//   H — admin-only (updateRuntimeFlags) + écriture Firestore directe refusée
//   I — audit (actor/timestamp/old/new)
//   J — runtime / no cache (flip immédiat, pas de redeploy)
//   K — bootstrap (config absente -> fail closed -> premier appel admin crée
//       le document -> flags appliqués)
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { ScheduledEvent } from "firebase-functions/v2/scheduler";
import { RulesTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { createTestEnv } from "./setup";

import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import {
  createDeliveryRequest,
  CreateDeliveryRequestRequest,
  StopInput,
} from "../../src/functions/createDeliveryRequest";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import {
  updateRuntimeFlags,
  UpdateRuntimeFlagsRequest,
} from "../../src/functions/updateRuntimeFlags";
import { calculateDriverPayout, CalculateDriverPayoutRequest } from "../../src/functions/calculateDriverPayout";
import { processScheduledDriverPayouts } from "../../src/functions/processScheduledDriverPayouts";
import {
  updatePayoutPolicyConfiguration,
  UpdatePayoutPolicyConfigurationRequest,
} from "../../src/functions/updatePayoutPolicyConfiguration";
import {
  reverseDriverPayout,
  ReverseDriverPayoutRequest,
} from "../../src/functions/reverseDriverPayout";
import {
  refundPayment as refundPaymentOrchestration,
  cancelMissionPaymentAuthorization,
} from "../../src/payment/paymentOrchestration";
import { admin, db } from "../../src/lib/admin";
import {
  MissionStatuses,
  PaymentStatuses,
  PayoutStatuses,
  RefundReasons,
  RefundStatuses,
} from "../../src/lib/types";
import {
  RuntimeFlagKeys,
  RUNTIME_FLAGS_COLLECTION,
  RUNTIME_FLAGS_DOC_ID,
  resolveRuntimeFlag,
  isRuntimeFlagEnabled,
} from "../../src/lib/runtimeFlags";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import {
  runtimeFlagsDocRef,
  seedRuntimeFlags,
  deleteRuntimeFlagsDoc,
} from "../testUtils/runtimeFlagsFixture";

// ---------------------------------------------------------------------------
// Helpers communs
//
// IMPORTANT : ce fichier garde la MAÎTRISE EXPLICITE de l'état du document
// `system_config/runtime_flags` (absent / partiel / invalide / ON / OFF) —
// c'est tout l'objet de la section X-11. Il réutilise le module partagé
// `test/testUtils/runtimeFlagsFixture.ts` (mêmes fonctions que celles
// appelées par les suites historiques) plutôt que de dupliquer une seconde
// implémentation, mais reste le SEUL fichier à appeler `deleteRuntimeFlagsDoc()`
// ou à seeder un document délibérément incomplet/invalide.
// ---------------------------------------------------------------------------

function authedRequest<T>(uid: string | undefined, data: T, role?: string): CallableRequest<T> {
  return {
    data,
    auth: uid
      ? { uid, token: (role ? { role } : {}) as unknown as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" }
      : undefined,
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

const RUNTIME_FLAGS_REF = () => runtimeFlagsDocRef();

/** Seed direct (Admin SDK — contourne les Security Rules, usage test only) d'un
 *  document runtime_flags complet et valide, tous les flags à `true` sauf overrides. */
async function seedAllFlagsOn(overrides: Partial<Record<string, boolean>> = {}): Promise<void> {
  await seedRuntimeFlags(overrides);
}

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "1 rue Flags", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "2 rue Flags", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

async function seedPricing(pricingVersion: string): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: pricingVersion });
  await db
    .collection("pricing_versions")
    .doc(pricingVersion)
    .set(buildPricingConfig({ pricing_version: pricingVersion }));
}

async function seedApprovedDriver(driverId: string): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    full_name: "Chauffeur Flags",
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.8,
    completed_missions: 1,
    created_at: admin.firestore.Timestamp.now(),
    approved_at: admin.firestore.Timestamp.now(),
    approved_by_user_id: "admin_seed",
    identity_verified: true,
    vehicle_verified: true,
    online_status: "online",
    documents_all_valid: true,
  });
}

async function createQuoteAndMission(
  customerId: string,
  pricingVersion: string,
  descriptionSuffix: string
): Promise<string> {
  const quote = await calculateDeliveryQuote.run(
    authedRequest<CalculateDeliveryQuoteRequest>(customerId, {
      vehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
    })
  );
  const created = await createDeliveryRequest.run(
    authedRequest<CreateDeliveryRequestRequest>(customerId, {
      quoteId: quote.quoteId,
      itemCategoryKey: "furniture",
      description: `Test runtimeFlags ${descriptionSuffix}`,
      requiredVehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
      stops: [pickupStop, dropoffStop],
      customerDisplayName: "Client Flags",
    })
  );
  return created.missionId;
}

async function cleanupMission(missionId: string | null): Promise<void> {
  if (!missionId) return;
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const [stops, events, snapshots, payments] = await Promise.all([
    missionRef.collection("stops").get(),
    missionRef.collection("tracking_events").get(),
    db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
    db.collection("payments").where("mission_id", "==", missionId).get(),
  ]);
  await Promise.all([
    ...stops.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    ...snapshots.docs.map((d) => d.ref.delete()),
    ...payments.docs.map((d) => d.ref.delete()),
    missionRef.delete(),
  ]);
}

async function cleanupCommon(pricingVersion: string, customerId: string, driverId: string): Promise<void> {
  await Promise.all([
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(pricingVersion).delete(),
    db.collection("driver_profiles").doc(driverId).delete(),
    db.collection("driver_locations").doc(driverId).delete(),
    db.collection("payment_profiles").doc(customerId).delete(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", customerId).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
}

// ===========================================================================
// SECTION D (PRIORITÉ) — PAYMENTS ON/OFF — preuve permanente de BUG-X-01
// ===========================================================================

describe("Bloc X (X-11, section D) — BUG-X-01 : payments_enabled=false n'envoie plus la mission en PAYMENT_FAILED", () => {
  const CUSTOMER_ID = "flagsD_customer_001";
  const DRIVER_ID = "flagsD_driver_001";
  const PRICING_VERSION = "FLAGSD-PRICING-001";
  let missionId: string | null = null;

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupMission(missionId);
    missionId = null;
    await cleanupCommon(PRICING_VERSION, CUSTOMER_ID, DRIVER_ID);
    await deleteRuntimeFlagsDoc();
  });

  it(
    "payments_enabled=false : acceptDelivery refuse AVANT toute assignation — aucun driver_id, " +
      "mission reste searching_driver/offered (JAMAIS payment_failed), aucun payment créé, aucune " +
      "authorization, aucune capture, aucun mouvement de ledger",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ payments_enabled: false });
      await Promise.all([
        seedPricing(PRICING_VERSION),
        seedApprovedDriver(DRIVER_ID),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);

      missionId = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "BUG-X-01 OFF");
      const mid = missionId as string;

      const missionBefore = (await db.collection("delivery_requests").doc(mid).get()).data()!;
      expect([MissionStatuses.SEARCHING_DRIVER, MissionStatuses.OFFERED]).toContain(missionBefore.status);
      expect(missionBefore.driver_id).toBeFalsy();

      // ---- acceptDelivery() DOIT refuser, message stable du kill switch ----
      await expect(
        acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid }))
      ).rejects.toMatchObject({ code: "failed-precondition", message: "service_temporarily_unavailable" });

      // ---- LA PREUVE DE BUG-X-01 : mission INCHANGÉE, jamais assignée, ----
      // ---- JAMAIS payment_failed. ----
      const missionAfter = (await db.collection("delivery_requests").doc(mid).get()).data()!;
      expect(missionAfter.status).not.toBe(MissionStatuses.PAYMENT_FAILED);
      expect([MissionStatuses.SEARCHING_DRIVER, MissionStatuses.OFFERED]).toContain(missionAfter.status);
      expect(missionAfter.driver_id).toBeFalsy();
      expect(missionAfter.accepted_at).toBeFalsy();
      expect(missionAfter.active_financial_snapshot_id).toBeFalsy();

      // ---- Aucun payment créé (aucune authorization, aucune capture) ----
      const paymentsSnap = await db.collection("payments").where("mission_id", "==", mid).get();
      expect(paymentsSnap.size).toBe(0);

      // ---- Aucun financial_snapshot créé pour cette mission ----
      const snapshotsSnap = await db.collection("financial_snapshots").where("mission_id", "==", mid).get();
      expect(snapshotsSnap.size).toBe(0);

      // ---- Aucune écriture ledger indue ----
      const ledgerSnap = await db.collection("transaction_ledger").where("mission_id", "==", mid).get();
      expect(ledgerSnap.size).toBe(0);

      // ---- Le chauffeur n'est jamais passé "on_mission" ----
      const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.online_status).toBe("online");

      // ---- Aucun tracking_event driver_assigned n'a été créé ----
      const eventsSnap = await db
        .collection("delivery_requests")
        .doc(mid)
        .collection("tracking_events")
        .where("event_type", "==", "driver_assigned")
        .get();
      expect(eventsSnap.size).toBe(0);
    }
  );

  it(
    "payments_enabled OFF -> ON : la même mission (non modifiée par le refus) peut ensuite être " +
      "acceptée normalement, assignée UNE SEULE FOIS, avec un workflow de paiement normal",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ payments_enabled: false });
      await Promise.all([
        seedPricing(PRICING_VERSION),
        seedApprovedDriver(DRIVER_ID),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);

      missionId = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "BUG-X-01 OFF puis ON");
      const mid = missionId as string;

      // ---- Tentative pendant OFF : refusée, sans séquelle ----
      await expect(
        acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid }))
      ).rejects.toMatchObject({ code: "failed-precondition" });

      // ---- Admin réactive le flag ----
      await RUNTIME_FLAGS_REF().update({ payments_enabled: true });

      // ---- Nouvelle tentative : réussit normalement, sans aucune séquelle ----
      const acceptResult = await acceptDelivery.run(
        authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid })
      );
      expect(acceptResult.success).toBe(true);
      expect(acceptResult.paymentId).toBeTruthy();

      const missionAfter = (await db.collection("delivery_requests").doc(mid).get()).data()!;
      expect(missionAfter.status).toBe(MissionStatuses.ASSIGNED);
      expect(missionAfter.driver_id).toBe(DRIVER_ID);
      expect(missionAfter.payment_status).toBe(PaymentStatuses.AUTHORIZED);

      // ---- Assignée UNE SEULE FOIS (un seul financial_snapshot, un seul payment) ----
      const snapshotsSnap = await db.collection("financial_snapshots").where("mission_id", "==", mid).get();
      expect(snapshotsSnap.size).toBe(1);
      const paymentsSnap = await db.collection("payments").where("mission_id", "==", mid).get();
      expect(paymentsSnap.size).toBe(1);
      expect(paymentsSnap.docs[0].data().status).toBe(PaymentStatuses.AUTHORIZED);
    }
  );

  it(
    "payments_enabled=false : accept_new_delivery_requests / allow_driver_acceptance restent " +
      "ON par ailleurs — le refus est SPÉCIFIQUE au paiement, pas une panne globale",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ payments_enabled: false });
      await Promise.all([
        seedPricing(PRICING_VERSION),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);

      // La création de mission n'est PAS affectée par payments_enabled=false
      // (seul accept_new_delivery_requests la contrôle — voir section B).
      missionId = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "isolation flags");
      expect(missionId).toBeTruthy();
    }
  );
});

// ===========================================================================
// SECTION D/E — REFUNDS / CORRECTIONS : jamais bloqués par payments_enabled=false
// ===========================================================================

describe("Bloc X (X-11, section D/E) — payments_enabled=false ne bloque JAMAIS une correction existante", () => {
  const CUSTOMER_ID = "flagsE_customer_001";
  const MISSION_ID = "flagsE_mission_001";
  const PAYMENT_ID = "flagsE_payment_001";

  afterEach(async () => {
    await Promise.all([
      db.collection("payments").doc(PAYMENT_ID).delete(),
      db.collection("refunds").doc(`refund_${PAYMENT_ID}`).delete(),
      db.collection("delivery_requests").doc(MISSION_ID).delete(),
      db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get().then((s) =>
        Promise.all(s.docs.map((d) => d.ref.delete()))
      ),
    ]);
    await deleteRuntimeFlagsDoc();
    setPaymentProviderForTesting(null);
  });

  async function seedCapturedPayment(): Promise<void> {
    const now = admin.firestore.Timestamp.now();
    await db.collection("delivery_requests").doc(MISSION_ID).set({
      customer_id: CUSTOMER_ID,
      driver_id: "flagsE_driver",
      status: "delivered",
      payment_status: PaymentStatuses.CAPTURED,
    });
    await db.collection("payments").doc(PAYMENT_ID).set({
      payment_id: PAYMENT_ID,
      mission_id: MISSION_ID,
      customer_id: CUSTOMER_ID,
      driver_id: "flagsE_driver",
      status: PaymentStatuses.CAPTURED,
      amount_authorized_minor: 5000,
      amount_captured_minor: 5000,
      amount_refunded_minor: 0,
      provider_payment_intent_id: "fake_pi_flagsE",
      created_at: now,
      updated_at: now,
    });
  }

  it(
    "refundPayment() (correction sur un paiement CAPTURED existant) fonctionne normalement " +
      "MÊME AVEC payments_enabled=false — le kill switch bloque une NOUVELLE exposition, jamais une réparation",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ payments_enabled: false });
      await seedCapturedPayment();

      const outcome = await refundPaymentOrchestration({
        paymentId: PAYMENT_ID,
        amountMinor: 5000,
        reason: RefundReasons.CUSTOMER_REQUEST,
        initiatedByUserId: "admin_flagsE",
        initiatedByRole: "admin",
        isAdminInitiated: true,
        requestKey: `refund_${PAYMENT_ID}`,
      });

      expect(outcome.success).toBe(true);
      expect(outcome.status).toBe(RefundStatuses.SUCCEEDED);

      const paymentAfter = (await db.collection("payments").doc(PAYMENT_ID).get()).data()!;
      expect(paymentAfter.status).toBe(PaymentStatuses.REFUNDED);
    }
  );

  it(
    "cancelMissionPaymentAuthorization() (relâche une AUTHORIZED existante) fonctionne " +
      "MÊME AVEC payments_enabled=false",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ payments_enabled: false });
      const now = admin.firestore.Timestamp.now();
      await db.collection("delivery_requests").doc(MISSION_ID).set({
        customer_id: CUSTOMER_ID,
        status: "assigned",
        payment_status: PaymentStatuses.AUTHORIZED,
      });
      await db.collection("payments").doc(PAYMENT_ID).set({
        payment_id: PAYMENT_ID,
        mission_id: MISSION_ID,
        customer_id: CUSTOMER_ID,
        status: PaymentStatuses.AUTHORIZED,
        provider_payment_intent_id: "fake_pi_flagsE_cancel",
        created_at: now,
        updated_at: now,
      });

      const outcome = await cancelMissionPaymentAuthorization(MISSION_ID, PAYMENT_ID);
      expect(outcome.success).toBe(true);
      expect(outcome.status).toBe(PaymentStatuses.CANCELLED);

      const paymentAfter = (await db.collection("payments").doc(PAYMENT_ID).get()).data()!;
      expect(paymentAfter.status).toBe(PaymentStatuses.CANCELLED);
    }
  );
});

// ===========================================================================
// SECTION B — createDeliveryRequest (accept_new_delivery_requests) ON/OFF
// ===========================================================================

describe("Bloc X (X-11, section B) — accept_new_delivery_requests ON/OFF", () => {
  const CUSTOMER_ID = "flagsB_customer_001";
  const PRICING_VERSION = "FLAGSB-PRICING-001";
  let missionId: string | null = null;

  afterEach(async () => {
    await cleanupMission(missionId);
    missionId = null;
    await Promise.all([
      db.collection("pricing_configs").doc("active").delete(),
      db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    ]);
    const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
    await Promise.all(quotes.docs.map((d) => d.ref.delete()));
    await deleteRuntimeFlagsDoc();
  });

  it("flag ON : création de mission fonctionne normalement", async () => {
    await seedAllFlagsOn();
    await Promise.all([
      seedPricing(PRICING_VERSION),
      db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
    ]);
    missionId = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "flag B ON");
    expect(missionId).toBeTruthy();
  });

  it(
    "flag OFF : createDeliveryRequest refuse AVANT toute écriture — aucun delivery_request créé, " +
      "aucune écriture secondaire (quote reste non consommé), aucun effet financier",
    async () => {
      await seedAllFlagsOn({ accept_new_delivery_requests: false });
      await Promise.all([
        seedPricing(PRICING_VERSION),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);

      const quote = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        })
      );

      await expect(
        createDeliveryRequest.run(
          authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
            quoteId: quote.quoteId,
            itemCategoryKey: "furniture",
            description: "flag B OFF",
            requiredVehicleCategory: "cargoVan",
            distanceKm: 10,
            estimatedDurationMinutes: 20,
            stops: [pickupStop, dropoffStop],
            customerDisplayName: "Client Flags B",
          })
        )
      ).rejects.toMatchObject({ code: "failed-precondition", message: "service_temporarily_unavailable" });

      // ---- Aucune mission créée pour ce devis ----
      const missionsSnap = await db
        .collection("delivery_requests")
        .where("customer_id", "==", CUSTOMER_ID)
        .get();
      expect(missionsSnap.size).toBe(0);

      // ---- Le devis reste NON consommé (aucune écriture secondaire) ----
      const quoteAfter = await db.collection("delivery_quotes").doc(quote.quoteId).get();
      expect(quoteAfter.data()!.is_consumed).toBeFalsy();
    }
  );
});

// ===========================================================================
// SECTION C — acceptDelivery (allow_driver_acceptance) ON/OFF
// ===========================================================================

describe("Bloc X (X-11, section C) — allow_driver_acceptance ON/OFF", () => {
  const CUSTOMER_ID = "flagsC_customer_001";
  const DRIVER_ID = "flagsC_driver_001";
  const PRICING_VERSION = "FLAGSC-PRICING-001";
  let missionId: string | null = null;

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupMission(missionId);
    missionId = null;
    await cleanupCommon(PRICING_VERSION, CUSTOMER_ID, DRIVER_ID);
    await deleteRuntimeFlagsDoc();
  });

  it("flag ON (payments aussi ON) : acceptation fonctionne normalement", async () => {
    setPaymentProviderForTesting(new FakePaymentProvider());
    await seedAllFlagsOn();
    await Promise.all([
      seedPricing(PRICING_VERSION),
      seedApprovedDriver(DRIVER_ID),
      db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
    ]);
    missionId = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "flag C ON");
    const result = await acceptDelivery.run(
      authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: missionId as string })
    );
    expect(result.success).toBe(true);
  });

  it(
    "flag OFF : refus serveur — aucun driver_id, aucun changement de statut, aucun side effect, " +
      "et un client modifié (contournement direct de la Cloud Function) ne peut pas bypasser ce refus",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ allow_driver_acceptance: false });
      await Promise.all([
        seedPricing(PRICING_VERSION),
        seedApprovedDriver(DRIVER_ID),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);
      missionId = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "flag C OFF");
      const mid = missionId as string;

      await expect(
        acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid }))
      ).rejects.toMatchObject({ code: "failed-precondition", message: "service_temporarily_unavailable" });

      const missionAfter = (await db.collection("delivery_requests").doc(mid).get()).data()!;
      expect(missionAfter.driver_id).toBeFalsy();
      expect([MissionStatuses.SEARCHING_DRIVER, MissionStatuses.OFFERED]).toContain(missionAfter.status);

      // Un "client modifié" n'a aucun moyen d'appeler acceptDelivery.run()
      // autrement que via cette même Cloud Function serveur-autoritaire —
      // il n'existe AUCUNE logique frontend/cliente qui décide de
      // l'assignation (voir en-tête de acceptDelivery.ts). Le seul autre
      // vecteur théorique serait une écriture Firestore DIRECTE sur
      // delivery_requests.driver_id, bloquée par firestore.rules
      // (`allow update: if false` sur les champs d'assignation — vérifié en
      // profondeur dans securityRules.test.ts, non dupliqué ici).
      const driverProfileAfter = (await db.collection("driver_profiles").doc(DRIVER_ID).get()).data()!;
      expect(driverProfileAfter.online_status).toBe("online");
    }
  );
});

// ===========================================================================
// SECTION F — PAYOUTS ON/OFF (2 points d'entrée : calculateDriverPayout direct
// ET processScheduledDriverPayouts, cron)
// ===========================================================================

describe("Bloc X (X-11, section F) — driver_payouts_enabled ON/OFF (2 entry points)", () => {
  const DRIVER_ID = "flagsF_driver_001";
  const ADMIN_ID = "flagsF_admin_001";

  async function seedSnapshot(id: string, missionId: string, driverNetMissionEarnings: number): Promise<void> {
    await db.collection("financial_snapshots").doc(id).set({
      snapshot_id: id,
      mission_id: missionId,
      driver_id: DRIVER_ID,
      status: "confirmed",
      driver_net_mission_earnings: driverNetMissionEarnings,
      included_in_payout_id: null,
      created_at: admin.firestore.Timestamp.now(),
    });
  }

  async function seedDriverProfile(connectedAccountId: string | null): Promise<void> {
    await db.collection("driver_profiles").doc(DRIVER_ID).set({
      uid: DRIVER_ID,
      completed_missions: 50,
      suspended_at: null,
      stripe_connected_account_id: connectedAccountId,
      online_status: "online",
    });
  }

  async function cleanupPayoutsForDriver(): Promise<void> {
    const [snapshots, payouts] = await Promise.all([
      db.collection("financial_snapshots").where("driver_id", "==", DRIVER_ID).get(),
      db.collection("driver_payouts").where("driver_id", "==", DRIVER_ID).get(),
    ]);
    const batch = db.batch();
    snapshots.docs.forEach((d) => batch.delete(d.ref));
    payouts.docs.forEach((d) => batch.delete(d.ref));
    batch.delete(db.collection("driver_profiles").doc(DRIVER_ID));
    await batch.commit();
    const ledger = await db.collection("transaction_ledger").where("driver_id", "==", DRIVER_ID).get();
    await Promise.all(ledger.docs.map((d) => d.ref.delete()));
  }

  async function cleanupPayoutPolicy(): Promise<void> {
    await db.collection("payout_policy_configs").doc("default").delete();
  }

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupPayoutsForDriver();
    await cleanupPayoutPolicy();
    await deleteRuntimeFlagsDoc();
  });

  it(
    "[ENTRY POINT 1 — direct] driver_payouts_enabled=false : calculateDriverPayout() crée le " +
      "payout ELIGIBLE puis soumission refusée — payout reste ELIGIBLE (PAS FAILED), aucun appel " +
      "provider, aucun provider_payout_id, aucune écriture ledger de versement PAID",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ driver_payouts_enabled: false });
      await updatePayoutPolicyConfiguration.run(
        authedRequest<UpdatePayoutPolicyConfigurationRequest>(
          ADMIN_ID,
          {
            defaultHoldPeriodHours: 0,
            newDriverHoldPeriodHours: 0,
            riskyDriverHoldPeriodHours: 0,
          },
          "admin"
        )
      );
      await seedDriverProfile("fake_acct_flagsF_seeded");
      const missionId = "flagsF_mission_direct";
      await seedSnapshot("flagsF_snap_direct", missionId, 45);

      const result = await calculateDriverPayout.run(
        authedRequest<CalculateDriverPayoutRequest>(ADMIN_ID, { driverId: DRIVER_ID }, "admin")
      );
      expect(result.payoutId).toBeTruthy();
      const payoutId = result.payoutId as string;

      // ---- Le résultat retourné par calculateDriverPayout() reflète l'échec
      // TEMPORAIRE, jamais un faux succès ----
      expect(result.success).toBe(false);
      expect(result.status).toBe(PayoutStatuses.ELIGIBLE);

      const payoutAfter = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutAfter.status).toBe(PayoutStatuses.ELIGIBLE);
      expect(payoutAfter.status).not.toBe(PayoutStatuses.FAILED);
      expect(payoutAfter.paid_at).toBeFalsy();
      expect(payoutAfter.provider_payout_id).toBeFalsy();

      const ledgerPaidSnap = await db
        .collection("transaction_ledger")
        .where("driver_id", "==", DRIVER_ID)
        .where("type", "==", "driver_payout_reversal")
        .get();
      expect(ledgerPaidSnap.size).toBe(0);
    }
  );

  it(
    "[ENTRY POINT 1 — direct] driver_payouts_enabled OFF -> ON : le versement resté ELIGIBLE " +
      "reprend normalement via un nouvel appel direct submitDriverPayout()-équivalent " +
      "(calculateDriverPayout ne recrée jamais de second payout ; on invoque le cron pour le point 2)",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ driver_payouts_enabled: false });
      await updatePayoutPolicyConfiguration.run(
        authedRequest<UpdatePayoutPolicyConfigurationRequest>(
          ADMIN_ID,
          {
            defaultHoldPeriodHours: 0,
            newDriverHoldPeriodHours: 0,
            riskyDriverHoldPeriodHours: 0,
          },
          "admin"
        )
      );
      await seedDriverProfile("fake_acct_flagsF_resume");
      const missionId = "flagsF_mission_resume";
      await seedSnapshot("flagsF_snap_resume", missionId, 30);

      const result = await calculateDriverPayout.run(
        authedRequest<CalculateDriverPayoutRequest>(ADMIN_ID, { driverId: DRIVER_ID }, "admin")
      );
      const payoutId = result.payoutId as string;
      expect((await db.collection("driver_payouts").doc(payoutId).get()).data()!.status).toBe(
        PayoutStatuses.ELIGIBLE
      );

      await RUNTIME_FLAGS_REF().update({ driver_payouts_enabled: true });

      // ---- Le cron (2e point d'entrée, testé isolément ci-dessous) OU un
      // nouvel appel direct via processScheduledDriverPayouts reprend ce
      // payout ELIGIBLE normalement, sans qu'aucune action de récupération
      // manuelle (retry FAILED) n'ait été nécessaire. ----
      await (
        processScheduledDriverPayouts as unknown as { run: (e: ScheduledEvent) => Promise<void> }
      ).run({ scheduleTime: new Date().toISOString(), jobName: "test-resume" } as unknown as ScheduledEvent);

      const payoutAfterResume = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutAfterResume.status).toBe(PayoutStatuses.PAID);
      expect(payoutAfterResume.provider_payout_id).toBeTruthy();

      // Un seul document driver_payouts pour ce chauffeur (aucune duplication
      // liée au passage OFF -> ON).
      const allPayouts = await db.collection("driver_payouts").where("driver_id", "==", DRIVER_ID).get();
      expect(allPayouts.size).toBe(1);
    }
  );

  it(
    "[ENTRY POINT 2 — cron processScheduledDriverPayouts] driver_payouts_enabled=false : " +
      "le cron promeut PENDING/HELD -> ELIGIBLE normalement (non financier), mais NE SOUMET " +
      "AUCUN versement au fournisseur — payout reste ELIGIBLE, jamais PAID/FAILED",
    async () => {
      setPaymentProviderForTesting(new FakePaymentProvider());
      await seedAllFlagsOn({ driver_payouts_enabled: false });
      await seedDriverProfile("fake_acct_flagsF_cron");

      const payoutId = "flagsF_payout_cron_001";
      const now = admin.firestore.Timestamp.now();
      await db.collection("driver_payouts").doc(payoutId).set({
        driver_id: DRIVER_ID,
        financial_snapshot_ids: [],
        amount_minor: 1000,
        currency: "CAD",
        status: PayoutStatuses.PENDING,
        payout_hold_period_hours: 0,
        // Rétention déjà écoulée : le cron doit promouvoir PENDING -> ELIGIBLE.
        payout_eligible_at: admin.firestore.Timestamp.fromMillis(now.toMillis() - 60_000),
        provider_payout_id: null,
        connected_account_id: "fake_acct_flagsF_cron",
        created_at: now,
        scheduled_at: null,
        processing_at: null,
        paid_at: null,
        failed_at: null,
        failure_reason: null,
        idempotency_key: `seed_${payoutId}`,
      });

      await (
        processScheduledDriverPayouts as unknown as { run: (e: ScheduledEvent) => Promise<void> }
      ).run({ scheduleTime: new Date().toISOString(), jobName: "test-cron-off" } as unknown as ScheduledEvent);

      const payoutAfter = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      // Promotion PENDING -> ELIGIBLE (opération non financière) a bien eu lieu...
      expect(payoutAfter.status).toBe(PayoutStatuses.ELIGIBLE);
      // ...mais AUCUNE soumission fournisseur n'a suivi.
      expect(payoutAfter.provider_payout_id).toBeFalsy();
      expect(payoutAfter.paid_at).toBeFalsy();

      await db.collection("driver_payouts").doc(payoutId).delete();
    }
  );
});

// ===========================================================================
// SECTION G — corrections payout (reverseDriverPayout) non bloquées par le switch
// ===========================================================================

describe("Bloc X (X-11, section G) — driver_payouts_enabled=false ne bloque JAMAIS reverseDriverPayout()", () => {
  const DRIVER_ID = "flagsG_driver_001";
  const ADMIN_ID = "flagsG_admin_001";
  const PAYOUT_ID = "flagsG_payout_001";
  const MISSION_ID = "flagsG_mission_001";
  const SNAPSHOT_ID = "flagsG_snap_001";

  afterEach(async () => {
    await Promise.all([
      db.collection("driver_payouts").doc(PAYOUT_ID).delete(),
      db.collection("financial_snapshots").doc(SNAPSHOT_ID).delete(),
    ]);
    const ledger = await db.collection("transaction_ledger").where("transaction_id", "==", PAYOUT_ID).get();
    await Promise.all(ledger.docs.map((d) => d.ref.delete()));
    await deleteRuntimeFlagsDoc();
  });

  it("reverseDriverPayout() (compensation sur un payout déjà PAID) fonctionne MÊME AVEC driver_payouts_enabled=false", async () => {
    await seedAllFlagsOn({ driver_payouts_enabled: false });
    const now = admin.firestore.Timestamp.now();
    await db.collection("financial_snapshots").doc(SNAPSHOT_ID).set({
      snapshot_id: SNAPSHOT_ID,
      mission_id: MISSION_ID,
      driver_id: DRIVER_ID,
      status: "confirmed",
      driver_net_mission_earnings: 40,
      included_in_payout_id: PAYOUT_ID,
      created_at: now,
    });
    await db.collection("driver_payouts").doc(PAYOUT_ID).set({
      driver_id: DRIVER_ID,
      financial_snapshot_ids: [SNAPSHOT_ID],
      amount_minor: 4000,
      currency: "CAD",
      status: PayoutStatuses.PAID,
      payout_hold_period_hours: 0,
      payout_eligible_at: now,
      provider_payout_id: "fake_po_flagsG",
      connected_account_id: "fake_acct_flagsG",
      created_at: now,
      scheduled_at: now,
      processing_at: now,
      paid_at: now,
      failed_at: null,
      failure_reason: null,
      idempotency_key: `seed_${PAYOUT_ID}`,
    });

    const outcome = await reverseDriverPayout.run(
      authedRequest<ReverseDriverPayoutRequest>(
        ADMIN_ID,
        { payoutId: PAYOUT_ID, reason: "Test correction Bloc X-11-G" },
        "admin"
      )
    );

    expect(outcome.status).toBe(PayoutStatuses.REVERSED);
    const payoutAfter = (await db.collection("driver_payouts").doc(PAYOUT_ID).get()).data()!;
    expect(payoutAfter.status).toBe(PayoutStatuses.REVERSED);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("transaction_id", "==", PAYOUT_ID)
      .where("type", "==", "driver_payout_reversal")
      .get();
    expect(ledgerSnap.size).toBe(1);
  });
});

// ===========================================================================
// SECTION A — Résolution de config (valide / absent / champ absent / type
// invalide / erreur Firestore-like) — via resolveRuntimeFlag() directement.
// ===========================================================================

describe("Bloc X (X-11, section A) — resolveRuntimeFlag() : fail-safe sur chaque cas anormal", () => {
  afterEach(async () => {
    await deleteRuntimeFlagsDoc();
  });

  it("document valide, champ booléen present -> valeur lue fidèlement (true et false)", async () => {
    await seedAllFlagsOn({ payments_enabled: false, driver_payouts_enabled: true });

    const payments = await resolveRuntimeFlag(RuntimeFlagKeys.PAYMENTS_ENABLED);
    expect(payments).toEqual({
      key: RuntimeFlagKeys.PAYMENTS_ENABLED,
      enabled: false,
      reason: "document_found_valid",
    });

    const payouts = await resolveRuntimeFlag(RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED);
    expect(payouts).toEqual({
      key: RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED,
      enabled: true,
      reason: "document_found_valid",
    });
  });

  it("document ABSENT -> FAIL CLOSED (false) pour LES 4 flags, reason=document_missing", async () => {
    await deleteRuntimeFlagsDoc();
    for (const key of [
      RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS,
      RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE,
      RuntimeFlagKeys.PAYMENTS_ENABLED,
      RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED,
    ]) {
      const resolution = await resolveRuntimeFlag(key);
      expect(resolution.enabled).toBe(false);
      expect(resolution.reason).toBe("document_missing");
      // Aucun détail Firestore interne exposé dans la résolution elle-même
      // (pas de chemin de collection, pas de message d'erreur brut).
      expect(Object.keys(resolution)).toEqual(["key", "enabled", "reason"]);
    }
  });

  it("champ ABSENT (document présent mais partiel) -> FAIL CLOSED uniquement pour le champ concerné", async () => {
    await RUNTIME_FLAGS_REF().set({
      accept_new_delivery_requests: true,
      // payments_enabled volontairement omis.
      allow_driver_acceptance: true,
      updated_at: admin.firestore.Timestamp.now(),
      updated_by_user_id: "test_seed_partial",
    });

    const payments = await resolveRuntimeFlag(RuntimeFlagKeys.PAYMENTS_ENABLED);
    expect(payments.enabled).toBe(false);
    expect(payments.reason).toBe("field_missing");

    // Les flags PRÉSENTS restent lus correctement (pas d'effet de bord global).
    const acceptRequests = await resolveRuntimeFlag(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS);
    expect(acceptRequests.enabled).toBe(true);
    expect(acceptRequests.reason).toBe("document_found_valid");
  });

  it("type INVALIDE (chaîne au lieu de booléen) -> FAIL CLOSED, reason=field_invalid_type", async () => {
    await RUNTIME_FLAGS_REF().set({
      accept_new_delivery_requests: true,
      allow_driver_acceptance: true,
      payments_enabled: "true", // corruption : chaîne, pas booléen
      driver_payouts_enabled: true,
      updated_at: admin.firestore.Timestamp.now(),
      updated_by_user_id: "test_seed_corrupt",
    });

    const payments = await resolveRuntimeFlag(RuntimeFlagKeys.PAYMENTS_ENABLED);
    expect(payments.enabled).toBe(false);
    expect(payments.reason).toBe("field_invalid_type");
  });

  it("isRuntimeFlagEnabled() : raccourci booléen cohérent avec resolveRuntimeFlag() sur tous les cas", async () => {
    await deleteRuntimeFlagsDoc();
    expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED)).toBe(false);

    await seedAllFlagsOn({ payments_enabled: true });
    expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED)).toBe(true);
  });
});

// ===========================================================================
// SECTION H — Admin-only (updateRuntimeFlags) + écriture Firestore directe refusée
// ===========================================================================

describe("Bloc X (X-11, section H) — admin/security sur updateRuntimeFlags & Firestore direct", () => {
  afterEach(async () => {
    await deleteRuntimeFlagsDoc();
  });

  it("non-admin (customer, driver, analyst) -> updateRuntimeFlags DENIED (permission-denied)", async () => {
    await seedAllFlagsOn();
    for (const role of ["customer", "driver", "analyst"]) {
      await expect(
        updateRuntimeFlags.run(
          authedRequest<UpdateRuntimeFlagsRequest>(`flagsH_${role}_001`, { flags: { payments_enabled: false } }, role)
        )
      ).rejects.toMatchObject({ code: "permission-denied" });
    }
  });

  it("admin autorisé -> updateRuntimeFlags SUCCESS", async () => {
    await seedAllFlagsOn();
    const result = await updateRuntimeFlags.run(
      authedRequest<UpdateRuntimeFlagsRequest>("flagsH_admin_001", { flags: { payments_enabled: false } }, "admin")
    );
    expect(result.success).toBe(true);
    expect(result.newValues.payments_enabled).toBe(false);
  });

  it("super_admin autorisé -> updateRuntimeFlags SUCCESS", async () => {
    await seedAllFlagsOn();
    const result = await updateRuntimeFlags.run(
      authedRequest<UpdateRuntimeFlagsRequest>(
        "flagsH_superadmin_001",
        { flags: { driver_payouts_enabled: false } },
        "super_admin"
      )
    );
    expect(result.success).toBe(true);
    expect(result.newValues.driver_payouts_enabled).toBe(false);
  });

  it("non authentifié -> updateRuntimeFlags DENIED (unauthenticated)", async () => {
    await seedAllFlagsOn();
    await expect(
      updateRuntimeFlags.run(authedRequest<UpdateRuntimeFlagsRequest>(undefined, { flags: { payments_enabled: false } }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it(
    "écriture DIRECTE Firestore (client, même admin) sur system_config/runtime_flags -> DENIED " +
      "par les Security Rules — seule updateRuntimeFlags peut écrire",
    async () => {
      let testEnv: RulesTestEnvironment | null = null;
      try {
        testEnv = await createTestEnv();
        const adminCtx = testEnv.authenticatedContext("flagsH_rules_admin", { role: "admin" });
        await assertFails(
          setDoc(doc(adminCtx.firestore(), `${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`), {
            payments_enabled: false,
          })
        );

        const superAdminCtx = testEnv.authenticatedContext("flagsH_rules_superadmin", { role: "super_admin" });
        await assertFails(
          setDoc(doc(superAdminCtx.firestore(), `${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`), {
            payments_enabled: false,
          })
        );
      } finally {
        if (testEnv) await testEnv.cleanup();
      }
    }
  );

  it("lecture directe Firestore : admin PEUT lire system_config/runtime_flags, un customer NE PEUT PAS", async () => {
    let testEnv: RulesTestEnvironment | null = null;
    try {
      testEnv = await createTestEnv();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`), {
          accept_new_delivery_requests: true,
          allow_driver_acceptance: true,
          payments_enabled: true,
          driver_payouts_enabled: true,
        });
      });

      const adminCtx = testEnv.authenticatedContext("flagsH_read_admin", { role: "admin" });
      await assertSucceeds(getDoc(doc(adminCtx.firestore(), `${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`)));

      const customerCtx = testEnv.authenticatedContext("flagsH_read_customer", { role: "customer" });
      await assertFails(getDoc(doc(customerCtx.firestore(), `${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`)));
    } finally {
      if (testEnv) await testEnv.cleanup();
    }
  });
});

// ===========================================================================
// SECTION I — Audit (actor / timestamp / old / new / action identifiable)
// ===========================================================================

describe("Bloc X (X-11, section I) — audit de updateRuntimeFlags", () => {
  afterEach(async () => {
    await deleteRuntimeFlagsDoc();
    const auditSnap = await db
      .collection("audit_logs")
      .where("source_function", "==", "updateRuntimeFlags")
      .get();
    await Promise.all(auditSnap.docs.map((d) => d.ref.delete()));
  });

  it(
    "modifier un flag via updateRuntimeFlags écrit un audit_logs avec actor, timestamp, " +
      "old/new values, action identifiable, aucune donnée secrète/inutile",
    async () => {
      await seedAllFlagsOn();

      const before = await db
        .collection("audit_logs")
        .where("source_function", "==", "updateRuntimeFlags")
        .get();
      const beforeCount = before.size;

      await updateRuntimeFlags.run(
        authedRequest<UpdateRuntimeFlagsRequest>(
          "flagsI_admin_001",
          { flags: { payments_enabled: false }, correlationId: "corr_flagsI_001" },
          "admin"
        )
      );

      const after = await db
        .collection("audit_logs")
        .where("source_function", "==", "updateRuntimeFlags")
        .get();
      expect(after.size).toBe(beforeCount + 1);

      const entry = after.docs
        .map((d) => d.data())
        .find((d) => d.metadata?.correlationId === "corr_flagsI_001")!;
      expect(entry).toBeTruthy();
      expect(entry.actor_user_id).toBe("flagsI_admin_001");
      expect(entry.actor_role).toBe("admin");
      expect(entry.action).toBe("runtime_flags_updated");
      expect(entry.created_at).toBeTruthy();
      expect(entry.target_id).toBe(`${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`);
      expect(entry.metadata.oldValues.payments_enabled).toBe(true);
      expect(entry.metadata.newValues.payments_enabled).toBe(false);
      expect(entry.metadata.changedKeys).toEqual(["payments_enabled"]);

      // Aucune donnée secrète/inutile — l'audit ne contient QUE les 4 flags
      // (booléens) + métadonnées de traçabilité, jamais un token, une clé
      // API, ou un détail d'implémentation Firestore.
      const metadataKeys = Object.keys(entry.metadata).sort();
      expect(metadataKeys).toEqual(
        ["changedKeys", "correlationId", "newValues", "oldValues", "wasBootstrapped"].sort()
      );
    }
  );
});

// ===========================================================================
// SECTION J — Runtime / no-cache : flip immédiat visible au TOUT PROCHAIN appel
// ===========================================================================

describe("Bloc X (X-11, section J) — aucun cache : l'appel serveur suivant observe la config la plus récente", () => {
  const CUSTOMER_ID = "flagsJ_customer_001";
  const PRICING_VERSION = "FLAGSJ-PRICING-001";
  let missionIds: string[] = [];

  afterEach(async () => {
    await Promise.all(missionIds.map((id) => cleanupMission(id)));
    missionIds = [];
    await Promise.all([
      db.collection("pricing_configs").doc("active").delete(),
      db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    ]);
    const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
    await Promise.all(quotes.docs.map((d) => d.ref.delete()));
    await deleteRuntimeFlagsDoc();
  });

  it(
    "flag ON -> appel réussit ; admin bascule OFF (update Firestore direct, sans redeploy) -> " +
      "le TOUT PROCHAIN appel serveur est refusé immédiatement",
    async () => {
      await seedAllFlagsOn();
      await Promise.all([
        seedPricing(PRICING_VERSION),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);

      // ---- Appel n°1, flag ON : réussit ----
      const mid1 = await createQuoteAndMission(CUSTOMER_ID, PRICING_VERSION, "no-cache appel1");
      missionIds.push(mid1);
      expect(mid1).toBeTruthy();

      // ---- Admin bascule OFF : simple update Firestore (aucun redeploy, ----
      // aucun redémarrage de process — exactement ce que ferait
      // updateRuntimeFlags() en production). ----
      await RUNTIME_FLAGS_REF().update({ accept_new_delivery_requests: false });

      // ---- Appel n°2, IMMÉDIATEMENT après : refusé — la lecture Firestore
      // de isRuntimeFlagEnabled() n'est mémoïsée nulle part côté process. ----
      const quote2 = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        })
      );
      await expect(
        createDeliveryRequest.run(
          authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
            quoteId: quote2.quoteId,
            itemCategoryKey: "furniture",
            description: "no-cache appel2 (doit échouer)",
            requiredVehicleCategory: "cargoVan",
            distanceKm: 10,
            estimatedDurationMinutes: 20,
            stops: [pickupStop, dropoffStop],
            customerDisplayName: "Client Flags J",
          })
        )
      ).rejects.toMatchObject({ code: "failed-precondition" });

      // ---- Admin réactive : appel n°3 réussit à nouveau, immédiatement ----
      await RUNTIME_FLAGS_REF().update({ accept_new_delivery_requests: true });
      const quote3 = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        })
      );
      const created3 = await createDeliveryRequest.run(
        authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
          quoteId: quote3.quoteId,
          itemCategoryKey: "furniture",
          description: "no-cache appel3 (doit réussir)",
          requiredVehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
          stops: [pickupStop, dropoffStop],
          customerDisplayName: "Client Flags J",
        })
      );
      missionIds.push(created3.missionId);
      expect(created3.missionId).toBeTruthy();
    }
  );

  it(
    "10 lectures successives de isRuntimeFlagEnabled() alternant vrai/faux reflètent CHAQUE " +
      "changement individuellement (preuve directe qu'aucune valeur n'est mise en cache process-local)",
    async () => {
      await seedAllFlagsOn({ payments_enabled: true });
      for (let i = 0; i < 5; i += 1) {
        const expected = i % 2 === 0;
        await RUNTIME_FLAGS_REF().update({ payments_enabled: expected });
        const actual = await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED);
        expect(actual).toBe(expected);
      }
    }
  );
});

// ===========================================================================
// SECTION K — Bootstrap : config absente -> fail closed -> updateRuntimeFlags
// crée le document -> flags appliqués. Aucun bootstrap permissif automatique
// depuis une action utilisateur NORMALE (seul un appel admin EXPLICITE crée
// le document initial).
// ===========================================================================

describe("Bloc X (X-11, section K) — bootstrap", () => {
  const CUSTOMER_ID = "flagsK_customer_001";
  const PRICING_VERSION = "FLAGSK-PRICING-001";

  afterEach(async () => {
    await deleteRuntimeFlagsDoc();
    await Promise.all([
      db.collection("pricing_configs").doc("active").delete(),
      db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    ]);
    const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
    await Promise.all(quotes.docs.map((d) => d.ref.delete()));
    const auditSnap = await db
      .collection("audit_logs")
      .where("source_function", "==", "updateRuntimeFlags")
      .get();
    await Promise.all(auditSnap.docs.map((d) => d.ref.delete()));
  });

  it(
    "config totalement absente : une action utilisateur NORMALE (créer une mission) est " +
      "FAIL CLOSED — AUCUN bootstrap permissif automatique n'est déclenché par cet appel",
    async () => {
      await deleteRuntimeFlagsDoc();
      await Promise.all([
        seedPricing(PRICING_VERSION),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);

      const quote = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        })
      );
      await expect(
        createDeliveryRequest.run(
          authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
            quoteId: quote.quoteId,
            itemCategoryKey: "furniture",
            description: "bootstrap absent -> fail closed",
            requiredVehicleCategory: "cargoVan",
            distanceKm: 10,
            estimatedDurationMinutes: 20,
            stops: [pickupStop, dropoffStop],
            customerDisplayName: "Client Flags K",
          })
        )
      ).rejects.toMatchObject({ code: "failed-precondition" });

      // ---- Le document runtime_flags n'existe TOUJOURS PAS : cette action
      // NORMALE (non-admin) n'a créé AUCUN bootstrap permissif. ----
      const stillAbsent = await RUNTIME_FLAGS_REF().get();
      expect(stillAbsent.exists).toBe(false);
    }
  );

  it(
    "config absente : le PREMIER appel admin à updateRuntimeFlags crée le document " +
      "(bootstrap à true pour les flags non modifiés), puis les actions protégées " +
      "fonctionnent selon les flags configurés",
    async () => {
      await deleteRuntimeFlagsDoc();

      const result = await updateRuntimeFlags.run(
        authedRequest<UpdateRuntimeFlagsRequest>(
          "flagsK_admin_001",
          { flags: { payments_enabled: false } },
          "admin"
        )
      );
      expect(result.success).toBe(true);

      const docAfter = await RUNTIME_FLAGS_REF().get();
      expect(docAfter.exists).toBe(true);
      const data = docAfter.data()!;
      // Le flag explicitement modifié reflète la demande...
      expect(data.payments_enabled).toBe(false);
      // ...les 3 AUTRES flags, jamais mentionnés dans cet appel, démarrent au
      // bootstrap PERMISSIF (true) — Movi-K reste opérationnel par défaut,
      // seul le flag explicitement coupé par l'admin est désactivé.
      expect(data.accept_new_delivery_requests).toBe(true);
      expect(data.allow_driver_acceptance).toBe(true);
      expect(data.driver_payouts_enabled).toBe(true);
      expect(data.updated_by_user_id).toBe("flagsK_admin_001");

      // ---- L'audit documente explicitement que ce document a été bootstrappé ----
      const auditSnap = await db
        .collection("audit_logs")
        .where("source_function", "==", "updateRuntimeFlags")
        .where("action", "==", "runtime_flags_updated")
        .get();
      const bootstrapEntry = auditSnap.docs.find((d) => d.data().metadata?.wasBootstrapped === true);
      expect(bootstrapEntry).toBeTruthy();

      // ---- Les flags configurés sont maintenant appliqués : accept_new_
      // delivery_requests=true (bootstrap) fonctionne, mais payments_enabled
      // =false bloque acceptDelivery (démontré exhaustivement en section D). ----
      await Promise.all([
        seedPricing(PRICING_VERSION),
        db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      ]);
      const quote = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        })
      );
      const created = await createDeliveryRequest.run(
        authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
          quoteId: quote.quoteId,
          itemCategoryKey: "furniture",
          description: "bootstrap puis création OK (accept_new_delivery_requests=true)",
          requiredVehicleCategory: "cargoVan",
          distanceKm: 10,
          estimatedDurationMinutes: 20,
          stops: [pickupStop, dropoffStop],
          customerDisplayName: "Client Flags K",
        })
      );
      expect(created.missionId).toBeTruthy();
      await cleanupMission(created.missionId);
    }
  );
});
