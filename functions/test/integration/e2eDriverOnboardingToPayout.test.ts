// ---------------------------------------------------------------------------
// Test d'intégration E2E — parcours COMPLET du chauffeur, depuis
// l'inscription (registerAsDriver) jusqu'au versement (calculateDriverPayout)
// (Phase 7, Bloc C, ACTION 2).
//
// CONTRAIREMENT à `e2eDeliveryLifecycle.test.ts` (qui seed un chauffeur DÉJÀ
// `approved` via `seedApprovedDriver()`), CE fichier comble le gap de
// couverture confirmé lors de la reconnaissance du Bloc C : aucun test
// existant n'exerçait `registerAsDriver` / `submitDriverForReview` /
// `approveDriver` comme de VRAIS appels de fonction. La chaîne testée ici
// est donc :
//
//   registerAsDriver (self-service, ajoute le rôle 'driver')
//   -> écriture directe driver_profiles (onboarding, non sensible — statut
//      'registration_incomplete', comme le fait FirebaseDriverRepository
//      côté Flutter)
//   -> écriture directe driver_vehicles (is_verified: false, comme le fait
//      submitDriverVehicle() côté Flutter)
//   -> écriture directe driver_documents (status: 'uploaded')
//   -> validateDriverDocument (analyst) x4 -> documents_all_valid = true
//   -> submitDriverForReview (driver)      => pending_review
//   -> approveDriver (analyst)             => approved
//   -> acceptDelivery (driver, mission ouverte préparée en parallèle)
//   -> updateMissionTrackingStatus x4 (driver_to_pickup, arrived_at_pickup
//      SONT enchaînés via completePickup ; in_transit, arrived_at_dropoff)
//   -> completePickup                      => picked_up
//   -> completeDelivery (avec proofOfDeliveryUrl obligatoire) => completed
//   -> vérification des earnings (ledger DRIVER_EARNING, financial_snapshot
//      confirmed)
//   -> calculateDriverPayout (admin)       => payout cohérent (amount_minor,
//      snapshot marqué included_in_payout_id)
//
// RÉUTILISE EXCLUSIVEMENT les vraies Cloud Functions / le vrai moteur de
// pricing — AUCUNE écriture directe de champ protégé (status approuvé,
// documents_all_valid, etc.) : ces champs sont TOUJOURS écrits par la Cloud
// Function correspondante, exactement comme en production.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { registerAsDriver } from "../../src/functions/registerAsDriver";
import { validateDriverDocument, ValidateDriverDocumentRequest } from "../../src/functions/validateDriverDocument";
import { submitDriverForReview } from "../../src/functions/submitDriverForReview";
import { approveDriver, ApproveDriverRequest } from "../../src/functions/approveDriver";
import { rejectDriver, RejectDriverRequest } from "../../src/functions/rejectDriver";
import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import { createDeliveryRequest, CreateDeliveryRequestRequest, StopInput } from "../../src/functions/createDeliveryRequest";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import {
  updateMissionTrackingStatus,
  UpdateMissionTrackingStatusRequest,
} from "../../src/functions/updateMissionTrackingStatus";
import { completePickup, CompletePickupRequest } from "../../src/functions/completePickup";
import { completeDelivery, CompleteDeliveryRequest } from "../../src/functions/completeDelivery";
import { calculateDriverPayout, CalculateDriverPayoutRequest } from "../../src/functions/calculateDriverPayout";
import { admin, authAdmin, db } from "../../src/lib/admin";
import { LedgerEntryTypes, MissionStatuses, DriverStatuses } from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";

const CUSTOMER_ID = "e2e_onb_customer_001";
const DRIVER_ID = "e2e_onb_driver_001";
const ANALYST_ID = "e2e_onb_analyst_001";
const ADMIN_ID = "e2e_onb_admin_001";
const VEHICLE_ID = "e2e_onb_vehicle_001";
const PRICING_VERSION = "E2E-ONB-PRICING-001";
const REQUIRED_DOCUMENT_TYPES = ["drivers_licence", "vehicle_registration", "insurance", "identity"];

/** Mock minimal d'un CallableRequest — même pattern que tous les autres
 * fichiers d'intégration de ce dossier (`acceptDeliveryConcurrency.test.ts`,
 * `e2eDeliveryLifecycle.test.ts`, `calculateDriverPayout.test.ts`).
 * `role` est optionnel car `registerAsDriver`/`submitDriverForReview`
 * lisent `ctx.roles`, alimenté par `token.roles` si présent, sinon par
 * `token.role` (voir `requireSignedIn` dans `lib/auth.ts`). */
function buildRequest<T>(
  uid: string,
  data: T,
  roles?: string[]
): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: (roles ? { role: roles[0], roles } : {}) as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

// `registerAsDriver` appelle RÉELLEMENT `authAdmin.setCustomUserClaims(uid, ...)`
// (contrairement à `acceptDelivery`/`submitDriverForReview`/etc. qui ne
// lisent que `request.auth.token` mocké) — l'émulateur Auth exige que
// l'utilisateur existe réellement avant d'accepter un `setCustomUserClaims`
// sur son uid (confirmé par l'erreur `no user record` obtenue au premier
// run de ce test). Aucun test existant du dépôt ne crée de VRAI utilisateur
// Auth emulé ; c'est le seul endroit où c'est nécessaire, car c'est la
// SEULE Cloud Function testée ici qui touche `authAdmin` pour de vrai.
async function seedAuthUser(uid: string): Promise<void> {
  await authAdmin.createUser({ uid, email: `${uid}@example.com` });
}

async function deleteAuthUserIfExists(uid: string): Promise<void> {
  await authAdmin.deleteUser(uid).catch(() => undefined);
}

async function seedPricing(): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

async function seedPaymentProfile(): Promise<void> {
  await db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID));
}

/** Reproduit EXACTEMENT ce que FirebaseDriverRepository.submitDriverOnboarding()
 * écrit côté Flutter : statut initial 'registration_incomplete' uniquement,
 * aucun champ protégé. */
async function seedDriverOnboardingProfile(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur Onboarding E2E",
    city: "Montréal",
    status: DriverStatuses.REGISTRATION_INCOMPLETE,
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 0,
    completed_missions: 0,
    created_at: admin.firestore.Timestamp.now(),
    identity_verified: false,
    vehicle_verified: false,
    online_status: "offline",
    documents_all_valid: false,
  });
}

/** Reproduit ce que FirebaseDriverRepository.submitDriverVehicle() écrit :
 * is_verified TOUJOURS false à la création (seule une Cloud Function/analyste
 * peut le faire passer à true — non exercé ici, non bloquant pour
 * l'éligibilité acceptDelivery qui ne lit que documents_all_valid /
 * accepted_vehicle_categories / status). */
async function seedDriverVehicle(): Promise<void> {
  await db.collection("driver_vehicles").doc(VEHICLE_ID).set({
    id: VEHICLE_ID,
    driver_id: DRIVER_ID,
    category: "cargoVan",
    make_model: "Ford Transit",
    year: 2021,
    plate: "E2E-ONB-001",
    max_payload_kg: 800,
    is_verified: false,
    created_at: admin.firestore.Timestamp.now(),
  });
}

/** Reproduit ce que submitDriverDocument() écrit côté Flutter : un document
 * par type requis, statut initial 'uploaded'. */
async function seedDriverDocuments(): Promise<string[]> {
  const ids: string[] = [];
  for (const type of REQUIRED_DOCUMENT_TYPES) {
    const ref = db.collection("driver_documents").doc();
    await ref.set({
      driver_id: DRIVER_ID,
      status: "uploaded",
      type,
      created_at: admin.firestore.Timestamp.now(),
    });
    ids.push(ref.id);
  }
  return ids;
}

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "10 rue Onboarding", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "20 rue Livraison", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

async function cleanupAll(missionId: string | null, documentIds: string[], payoutId: string | null): Promise<void> {
  const ops: Promise<unknown>[] = [
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("driver_vehicles").doc(VEHICLE_ID).delete(),
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    ...documentIds.map((id) => db.collection("driver_documents").doc(id).delete()),
  ];

  if (missionId) {
    const missionRef = db.collection("delivery_requests").doc(missionId);
    const [stops, events, ledger, snapshots, payments] = await Promise.all([
      missionRef.collection("stops").get(),
      missionRef.collection("tracking_events").get(),
      db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
      db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
      db.collection("payments").where("mission_id", "==", missionId).get(),
    ]);
    ops.push(
      ...stops.docs.map((d) => d.ref.delete()),
      ...events.docs.map((d) => d.ref.delete()),
      ...ledger.docs.map((d) => d.ref.delete()),
      ...snapshots.docs.map((d) => d.ref.delete()),
      ...payments.docs.map((d) => d.ref.delete()),
      missionRef.delete()
    );
  }

  if (payoutId) {
    ops.push(
      db
        .collection("transaction_ledger")
        .where("transaction_id", "==", payoutId)
        .get()
        .then((s) => Promise.all(s.docs.map((d) => d.ref.delete()))),
      db.collection("driver_payouts").doc(payoutId).delete()
    );
  }

  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  ops.push(...quotes.docs.map((d) => d.ref.delete()));

  const auditTargets = [DRIVER_ID, missionId, payoutId].filter((x): x is string => !!x);
  for (const target of auditTargets) {
    ops.push(
      db
        .collection("audit_logs")
        .where("target_id", "==", target)
        .get()
        .then((s) => Promise.all(s.docs.map((d) => d.ref.delete())))
    );
  }

  await Promise.all(ops);
}

describe("E2E — parcours chauffeur complet : registerAsDriver -> ... -> calculateDriverPayout", () => {
  let missionId: string | null = null;
  let documentIds: string[] = [];
  let payoutId: string | null = null;

  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  afterEach(async () => {
    await cleanupAll(missionId, documentIds, payoutId);
    await deleteAuthUserIfExists(DRIVER_ID);
    missionId = null;
    documentIds = [];
    payoutId = null;
  });

  it(
    "chaîne réelle complète : registerAsDriver -> onboarding -> véhicule -> documents -> " +
      "submitDriverForReview -> approveDriver -> acceptDelivery -> trajet complet -> " +
      "completeDelivery -> earnings -> calculateDriverPayout",
    async () => {
      // ---- 1. Inscription self-service : ajoute le rôle 'driver' ----
      // `registerAsDriver` appelle RÉELLEMENT `authAdmin.setCustomUserClaims`,
      // l'émulateur Auth exige donc un utilisateur existant au préalable.
      await seedAuthUser(DRIVER_ID);
      const registerResult = await registerAsDriver.run(buildRequest(DRIVER_ID, undefined));
      expect(registerResult.success).toBe(true);
      expect(registerResult.roles).toContain("driver");

      // ---- 2. Onboarding : profil + véhicule + documents (écritures NON
      // sensibles, statut initial imposé par firestore.rules) ----
      await Promise.all([seedDriverOnboardingProfile(), seedDriverVehicle()]);
      documentIds = await seedDriverDocuments();

      let driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.status).toBe(DriverStatuses.REGISTRATION_INCOMPLETE);
      expect(driverSnap.data()!.documents_all_valid).toBe(false);

      // ---- 3. Analyste valide chaque document (seul point d'entrée pour
      // faire évoluer driver_documents.status et recalculer
      // documents_all_valid) ----
      for (const docId of documentIds) {
        const result = await validateDriverDocument.run(
          buildRequest<ValidateDriverDocumentRequest>(
            ANALYST_ID,
            { documentId: docId, newStatus: "approved" },
            ["analyst"]
          )
        );
        expect(result.success).toBe(true);
      }
      driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.documents_all_valid).toBe(true);

      // ---- 4. Chauffeur soumet sa candidature pour révision ----
      const submitResult = await submitDriverForReview.run(buildRequest(DRIVER_ID, undefined, ["driver"]));
      expect(submitResult.status).toBe(DriverStatuses.PENDING_REVIEW);
      driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.status).toBe(DriverStatuses.PENDING_REVIEW);

      // ---- 5. Analyste approuve le chauffeur ----
      const approveResult = await approveDriver.run(
        buildRequest<ApproveDriverRequest>(ANALYST_ID, { driverId: DRIVER_ID }, ["analyst"])
      );
      expect(approveResult.success).toBe(true);
      driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.status).toBe(DriverStatuses.APPROVED);
      expect(driverSnap.data()!.approved_by_user_id).toBe(ANALYST_ID);

      // ---- 6. Passage en ligne (écriture directe côté Flutter,
      // autorisée par firestore.rules UNIQUEMENT si status == 'approved' —
      // ici on simule directement l'état "online" attendu après ce
      // passage, l'objectif du test n'étant pas de re-couvrir la règle
      // elle-même mais la disponibilité pour acceptDelivery) ----
      await db.collection("driver_profiles").doc(DRIVER_ID).update({ online_status: "online" });

      // ---- 7. Client crée une mission ouverte (mission disponible) ----
      await Promise.all([seedPricing(), seedPaymentProfile()]);
      const quote = await calculateDeliveryQuote.run(
        buildRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 12,
          estimatedDurationMinutes: 25,
        })
      );
      const created = await createDeliveryRequest.run(
        buildRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
          quoteId: quote.quoteId,
          itemCategoryKey: "furniture",
          description: "Déménagement E2E onboarding->payout — canapé.",
          requiredVehicleCategory: "cargoVan",
          distanceKm: 12,
          estimatedDurationMinutes: 25,
          stops: [pickupStop, dropoffStop],
          customerDisplayName: "Client Onboarding E2E",
        })
      );
      const id: string = created.missionId;
      missionId = id;

      let missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.SEARCHING_DRIVER);

      // ---- 8. Le chauffeur NOUVELLEMENT approuvé accepte la mission ----
      const accepted = await acceptDelivery.run(
        buildRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: id }, ["driver"])
      );
      expect(accepted.success).toBe(true);
      const snapshotId = accepted.snapshotId;
      expect(snapshotId).toBeTruthy();

      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
      expect(missionSnap.data()!.driver_id).toBe(DRIVER_ID);

      // ---- 9. Trajet complet : driver_to_pickup -> arrived_at_pickup ----
      await updateMissionTrackingStatus.run(
        buildRequest<UpdateMissionTrackingStatusRequest>(
          DRIVER_ID,
          { missionId: id, targetStatus: MissionStatuses.DRIVER_TO_PICKUP },
          ["driver"]
        )
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.DRIVER_TO_PICKUP);

      await updateMissionTrackingStatus.run(
        buildRequest<UpdateMissionTrackingStatusRequest>(
          DRIVER_ID,
          { missionId: id, targetStatus: MissionStatuses.ARRIVED_AT_PICKUP },
          ["driver"]
        )
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ARRIVED_AT_PICKUP);

      // ---- 10. completePickup -> picked_up ----
      await completePickup.run(
        buildRequest<CompletePickupRequest>(DRIVER_ID, { missionId: id }, ["driver"])
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.PICKED_UP);

      // ---- 11. in_transit -> arrived_at_dropoff ----
      await updateMissionTrackingStatus.run(
        buildRequest<UpdateMissionTrackingStatusRequest>(
          DRIVER_ID,
          { missionId: id, targetStatus: MissionStatuses.IN_TRANSIT },
          ["driver"]
        )
      );
      await updateMissionTrackingStatus.run(
        buildRequest<UpdateMissionTrackingStatusRequest>(
          DRIVER_ID,
          { missionId: id, targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF },
          ["driver"]
        )
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ARRIVED_AT_DROPOFF);

      // ---- 12. Preuve de livraison OBLIGATOIRE + completeDelivery -> completed ----
      const PROOF_URL = `https://storage.googleapis.com/movik-test/delivery_proofs/${id}/proof.jpg`;
      const completed = await completeDelivery.run(
        buildRequest<CompleteDeliveryRequest>(
          DRIVER_ID,
          { missionId: id, proofOfDeliveryUrl: PROOF_URL },
          ["driver"]
        )
      );
      expect(completed.success).toBe(true);

      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.COMPLETED);
      expect(missionSnap.data()!.proof_of_delivery_url).toBe(PROOF_URL);

      // ==== 13. EARNINGS VISIBLES : financial_snapshot confirmé + ledger
      // DRIVER_EARNING + completed_missions incrémenté ====
      const snapshotSnap = await db.collection("financial_snapshots").doc(snapshotId).get();
      expect(snapshotSnap.data()!.status).toBe("confirmed");
      expect(snapshotSnap.data()!.driver_net_mission_earnings).toBeGreaterThan(0);

      const ledgerEntries = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", id)
        .get();
      const driverEarning = ledgerEntries.docs.find(
        (d) => d.data().type === LedgerEntryTypes.DRIVER_EARNING
      )!;
      expect(driverEarning).toBeTruthy();
      expect(driverEarning.data().party).toBe("driver");
      expect(driverEarning.data().status).toBe("confirmed");

      driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.completed_missions).toBe(1); // 0 (seed) + 1
      expect(driverSnap.data()!.online_status).toBe("online");

      // ==== 14. PAYOUT COHÉRENT : calculateDriverPayout (admin) ====
      const payoutResult = await calculateDriverPayout.run(
        buildRequest<CalculateDriverPayoutRequest>(ADMIN_ID, { driverId: DRIVER_ID }, ["admin"])
      );
      expect(payoutResult.success).toBe(true);
      expect(payoutResult.payoutId).toBeTruthy();
      payoutId = payoutResult.payoutId as string;
      expect(payoutResult.amountMinor).toBeGreaterThan(0);

      const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
      expect(payoutSnap.exists).toBe(true);
      const payoutData = payoutSnap.data()!;
      expect(payoutData.driver_id).toBe(DRIVER_ID);
      expect(payoutData.financial_snapshot_ids).toContain(snapshotId);
      // Nouveau chauffeur (0 mission complétée avant cette mission -> < 5) :
      // la politique par défaut (bootstrap) applique new_driver_hold_period_hours
      // (168h) -> le versement reste PENDING (jamais ELIGIBLE immédiatement),
      // cohérent avec le profil de risque "nouveau chauffeur".
      expect(payoutData.status).toBe("pending");
      expect(payoutData.payout_hold_period_hours).toBe(168);

      // Le snapshot est désormais marqué comme inclus dans ce payout —
      // ne pourra plus être agrégé une seconde fois (non-duplication).
      const snapshotAfterPayout = await db.collection("financial_snapshots").doc(snapshotId).get();
      expect(snapshotAfterPayout.data()!.included_in_payout_id).toBe(payoutId);
    }
  );
});

// ---------------------------------------------------------------------------
// Cas négatifs — chaîne d'onboarding elle-même (complète le gap identifié :
// aucun test existant n'exerçait rejectDriver / re-soumission après rejet).
// ---------------------------------------------------------------------------
describe("E2E onboarding — cas négatifs (rejet puis re-soumission)", () => {
  afterEach(async () => {
    await cleanupAll(null, [], null);
  });

  it("un chauffeur rejeté peut être re-soumis après correction (rejected n'est PAS un cul-de-sac)", async () => {
    await seedDriverOnboardingProfile();
    await db.collection("driver_profiles").doc(DRIVER_ID).update({ status: DriverStatuses.PENDING_REVIEW });

    const rejectResult = await rejectDriver.run(
      buildRequest<RejectDriverRequest>(
        ANALYST_ID,
        { driverId: DRIVER_ID, reason: "Permis illisible sur la photo." },
        ["analyst"]
      )
    );
    expect(rejectResult.success).toBe(true);

    let driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.REJECTED);
    expect(driverSnap.data()!.rejection_reason).toBeTruthy();

    // rejected n'est PAS dans ALLOWED_PREVIOUS_STATUSES de submitDriverForReview
    // -> une re-soumission directe doit échouer tant que le chauffeur n'a pas
    // corrigé son dossier (repassage par 'registration_incomplete' ou
    // 'documents_required', jamais automatique depuis 'rejected').
    await expect(submitDriverForReview.run(buildRequest(DRIVER_ID, undefined, ["driver"]))).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });

  it("approveDriver refuse l'auto-approbation (analyste == chauffeur cible)", async () => {
    await seedDriverOnboardingProfile();
    await db.collection("driver_profiles").doc(DRIVER_ID).update({ status: DriverStatuses.PENDING_REVIEW });

    await expect(
      approveDriver.run(
        buildRequest<ApproveDriverRequest>(DRIVER_ID, { driverId: DRIVER_ID }, ["analyst", "driver"])
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.PENDING_REVIEW);
  });

  it("approveDriver refuse si l'appelant n'a pas au moins le rôle analyst", async () => {
    await seedDriverOnboardingProfile();
    await db.collection("driver_profiles").doc(DRIVER_ID).update({ status: DriverStatuses.PENDING_REVIEW });

    await expect(
      approveDriver.run(
        buildRequest<ApproveDriverRequest>("stranger_customer_id", { driverId: DRIVER_ID }, ["customer"])
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("submitDriverForReview refuse un appelant sans le rôle driver", async () => {
    await seedDriverOnboardingProfile();

    await expect(
      submitDriverForReview.run(buildRequest(DRIVER_ID, undefined, ["customer"]))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});
