// ---------------------------------------------------------------------------
// Test d'intégration — Phase 7, Bloc B (E2E Client, cas négatif : annulation
// après assignation avec paiement AUTORISÉ).
//
// BUG DÉCOUVERT (Phase 7, avant correction) : `firestore.rules` permet au
// client d'annuler sa mission une fois `driver_id` assigné (status ->
// 'cancelled'), et `acceptDelivery()` a DÉJÀ autorisé un paiement Stripe
// (`payments/{id}.status === 'authorized'`) à ce stade. Aucune Cloud
// Function n'appelait `PaymentProvider.cancelAuthorization()` sur cette
// transition : l'autorisation restait active côté Stripe (fonds bloqués sur
// la carte du client, jusqu'à expiration naturelle ~7 jours) et
// `payments/{id}.status` restait à tort 'authorized' alors que la mission
// était déjà annulée.
//
// CORRECTIF : `onMissionEndedClearTracking` (déjà le SEUL point
// d'interception fiable de l'annulation cliente directe, voir son
// commentaire d'en-tête) appelle désormais
// `cancelMissionPaymentAuthorization()` quand la mission transite vers
// 'cancelled' ET possède un `active_payment_id` dont le paiement est encore
// à l'état AUTHORIZED (jamais capturé). Aucun changement de comportement
// pour CAPTURED (remboursement, hors périmètre de ce trigger).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import { createDeliveryRequest, CreateDeliveryRequestRequest, StopInput } from "../../src/functions/createDeliveryRequest";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import { onMissionEndedClearTracking } from "../../src/functions/onMissionEndedClearTracking";
import { admin, db } from "../../src/lib/admin";
import { PaymentStatuses } from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";

const CUSTOMER_ID = "cancel_release_customer_001";
const DRIVER_ID = "cancel_release_driver_001";
const PRICING_VERSION = "CANCEL-RELEASE-PRICING-001";

function authedRequest<T>(uid: string | undefined, data: T): CallableRequest<T> {
  return {
    data,
    auth: uid ? { uid, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" } : undefined,
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function fakeSnap(data: Record<string, unknown> | undefined): QueryDocumentSnapshot {
  return { data: () => data } as unknown as QueryDocumentSnapshot;
}

function buildEvent(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
  missionId: string
): FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }> {
  return {
    data: { before: fakeSnap(before), after: fakeSnap(after) } as unknown as Change<QueryDocumentSnapshot>,
    params: { missionId },
  } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }>;
}

async function seedPricing(): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

async function seedApprovedDriver(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur Annulation",
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

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "1 rue Annulation", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "2 rue Fin", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

async function cleanupAll(missionId: string | null): Promise<void> {
  if (!missionId) return;
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const [stops, events, ledger, snapshots, payments] = await Promise.all([
    missionRef.collection("stops").get(),
    missionRef.collection("tracking_events").get(),
    db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
    db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
    db.collection("payments").where("mission_id", "==", missionId).get(),
  ]);
  const paymentIds = payments.docs.map((d) => d.id);
  await Promise.all([
    ...stops.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    ...ledger.docs.map((d) => d.ref.delete()),
    ...snapshots.docs.map((d) => d.ref.delete()),
    ...payments.docs.map((d) => d.ref.delete()),
    missionRef.delete(),
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    ...paymentIds.map((pid) =>
      db.collection("idempotency_keys").doc(`cancelAuthorization:${pid}`).delete()
    ),
    db
      .collection("audit_logs")
      .where("target_id", "in", paymentIds.length > 0 ? paymentIds : ["__none__"])
      .get()
      .then((s) => Promise.all(s.docs.map((d) => d.ref.delete()))),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
}

describe("Phase 7 — Bloc B : annulation client après assignation LIBÈRE l'autorisation de paiement", () => {
  let missionId: string | null = null;

  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  afterEach(async () => {
    await cleanupAll(missionId);
    missionId = null;
  });

  it("le paiement AUTHORIZED passe à CANCELLED (et mission.payment_status aussi) quand le client annule une mission assignée", async () => {
    await Promise.all([seedPricing(), seedApprovedDriver(), db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID))]);

    const quote = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
        vehicleCategory: "cargoVan",
        distanceKm: 12,
        estimatedDurationMinutes: 25,
      })
    );
    const created = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
        quoteId: quote.quoteId,
        itemCategoryKey: "furniture",
        description: "Test annulation post-assignation.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 12,
        estimatedDurationMinutes: 25,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Annulation",
      })
    );
    missionId = created.missionId;
    const mid = missionId as string;

    // Le chauffeur accepte -> createAndAuthorizeMissionPayment() autorise un
    // paiement réel (FakePaymentProvider) : payments/{id}.status = AUTHORIZED.
    const acceptResult = await acceptDelivery.run(
      authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid })
    );
    expect(acceptResult.paymentId).toBeTruthy();
    const paymentId = acceptResult.paymentId!;

    const paymentBeforeSnap = await db.collection("payments").doc(paymentId).get();
    expect(paymentBeforeSnap.data()!.status).toBe(PaymentStatuses.AUTHORIZED);

    const missionSnapBefore = await db.collection("delivery_requests").doc(mid).get();
    const missionBefore = missionSnapBefore.data()!;
    expect(missionBefore.payment_status).toBe(PaymentStatuses.AUTHORIZED);
    expect(missionBefore.driver_id).toBe(DRIVER_ID);

    // ---- Le client annule (écriture permise par firestore.rules : status
    // -> 'cancelled', champs financiers inchangés) ----
    const missionRef = db.collection("delivery_requests").doc(mid);
    await missionRef.update({
      status: "cancelled",
      cancellation_reason: "changement de plan (test)",
    });
    const missionAfterCancelSnap = await missionRef.get();
    const missionAfterCancel = missionAfterCancelSnap.data()!;

    // Le VRAI trigger onDocumentUpdated ne se déclenche pas sous
    // `--only firestore,auth,storage` (voir note d'architecture dans
    // e2eDeliveryLifecycle.test.ts) : on l'invoque manuellement avec
    // l'état avant/après RÉEL, exactement comme les autres tests E2E de ce
    // dossier.
    await onMissionEndedClearTracking.run(
      buildEvent(missionBefore, missionAfterCancel, mid)
    );

    // ---- Assertions du correctif ----
    const paymentAfterSnap = await db.collection("payments").doc(paymentId).get();
    const paymentAfter = paymentAfterSnap.data()!;
    expect(paymentAfter.status).toBe(PaymentStatuses.CANCELLED);
    expect(paymentAfter.cancelled_at).toBeTruthy();

    const missionFinalSnap = await missionRef.get();
    expect(missionFinalSnap.data()!.payment_status).toBe(PaymentStatuses.CANCELLED);

    // Traçabilité : un audit_log documente l'annulation de l'autorisation.
    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", paymentId)
      .where("action", "==", "payment_authorization_cancelled")
      .get();
    expect(auditSnap.size).toBe(1);
  });

  it("[idempotence] rejouer le trigger sur une mission DÉJÀ cancelled+payment déjà CANCELLED ne relance pas cancelAuthorization (pas de double appel provider)", async () => {
    await Promise.all([seedPricing(), seedApprovedDriver(), db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID))]);

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
        description: "Test idempotence annulation.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 10,
        estimatedDurationMinutes: 20,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Idempotence",
      })
    );
    missionId = created.missionId;
    const mid = missionId as string;

    const acceptResult = await acceptDelivery.run(
      authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid })
    );
    const paymentId = acceptResult.paymentId!;

    const missionRef = db.collection("delivery_requests").doc(mid);
    const missionBeforeSnap = await missionRef.get();
    const missionBefore = missionBeforeSnap.data()!;

    await missionRef.update({ status: "cancelled", cancellation_reason: "test idempotence" });
    const missionAfterSnap = await missionRef.get();
    const missionAfter = missionAfterSnap.data()!;

    // Premier passage : annule réellement l'autorisation.
    await onMissionEndedClearTracking.run(buildEvent(missionBefore, missionAfter, mid));
    const paymentAfterFirst = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(paymentAfterFirst.status).toBe(PaymentStatuses.CANCELLED);
    const cancelledAtFirst = paymentAfterFirst.cancelled_at;

    // Deuxième passage (simulateur de livraison "at-least-once" du trigger) :
    // le paiement est déjà CANCELLED, aucune ré-exécution ne doit se produire
    // (pas d'erreur de transition invalide, cancelled_at inchangé).
    await onMissionEndedClearTracking.run(buildEvent(missionBefore, missionAfter, mid));
    const paymentAfterSecond = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(paymentAfterSecond.status).toBe(PaymentStatuses.CANCELLED);
    expect(paymentAfterSecond.cancelled_at).toEqual(cancelledAtFirst);

    // Un seul audit_log 'payment_authorization_cancelled' doit exister (pas
    // deux), preuve qu'aucun second appel provider n'a été tenté.
    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", paymentId)
      .where("action", "==", "payment_authorization_cancelled")
      .get();
    expect(auditSnap.size).toBe(1);
  });

  it("[négatif] un paiement DÉJÀ CAPTURED n'est jamais annulé par ce trigger (hors périmètre — remboursement uniquement)", async () => {
    await Promise.all([seedPricing(), seedApprovedDriver(), db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID))]);

    const quote = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
        vehicleCategory: "cargoVan",
        distanceKm: 8,
        estimatedDurationMinutes: 15,
      })
    );
    const created = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
        quoteId: quote.quoteId,
        itemCategoryKey: "furniture",
        description: "Test paiement déjà capturé.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 8,
        estimatedDurationMinutes: 15,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Capturé",
      })
    );
    missionId = created.missionId;
    const mid = missionId as string;

    const acceptResult = await acceptDelivery.run(
      authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid })
    );
    const paymentId = acceptResult.paymentId!;

    // Force manuellement le paiement en CAPTURED (simule une mission déjà
    // livrée + capturée, puis "annulée" a posteriori par erreur/glitch —
    // cas défensif : ne doit JAMAIS déclencher cancelAuthorization sur un
    // paiement déjà capturé, la voie normale est refundPayment()).
    await db.collection("payments").doc(paymentId).update({
      status: PaymentStatuses.CAPTURED,
      captured_at: admin.firestore.Timestamp.now(),
      amount_captured_minor: 1,
    });

    const missionRef = db.collection("delivery_requests").doc(mid);
    const missionBeforeSnap = await missionRef.get();
    const missionBefore = missionBeforeSnap.data()!;
    await missionRef.update({ status: "cancelled", cancellation_reason: "post-capture (défensif)" });
    const missionAfter = (await missionRef.get()).data()!;

    await onMissionEndedClearTracking.run(buildEvent(missionBefore, missionAfter, mid));

    const paymentAfter = (await db.collection("payments").doc(paymentId).get()).data()!;
    // Reste CAPTURED : ce trigger ne touche jamais un paiement déjà capturé.
    expect(paymentAfter.status).toBe(PaymentStatuses.CAPTURED);
  });
});
