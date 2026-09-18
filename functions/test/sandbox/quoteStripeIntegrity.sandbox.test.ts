// -----------------------------------------------------------------------------
// Validation MANUELLE contre un vrai Stripe Sandbox.
//
// Ce fichier n'est inclus ni dans `test:unit` ni dans `test:integration`.
// Il est exécuté uniquement par le workflow `stripe-sandbox-validation.yml`,
// avec une clé GitHub Actions protégée et les émulateurs Firebase.
//
// Garde-fous :
// - refuse toute clé qui ne commence pas par `sk_test_`;
// - refuse de toucher Firestore hors émulateur;
// - ne capture aucun paiement et n'effectue aucun versement;
// - annule l'autorisation simulée et supprime le Customer de test.
// -----------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import Stripe from "stripe";

import {
  calculateDeliveryQuote,
  CalculateDeliveryQuoteRequest,
} from "../../src/functions/calculateDeliveryQuote";
import {
  createDeliveryRequest,
  CreateDeliveryRequestRequest,
  StopInput,
} from "../../src/functions/createDeliveryRequest";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import {
  updateTaxConfiguration,
  UpdateTaxConfigurationRequest,
} from "../../src/functions/updateTaxConfiguration";
import { admin, db } from "../../src/lib/admin";
import { toMinorUnits } from "../../src/lib/money";
import { StripeProvider } from "../../src/payment/stripeProvider";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { buildPricingConfig } from "../unit/fixtures";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

const CUSTOMER_ID = "stripe_sandbox_customer";
const DRIVER_ID = "stripe_sandbox_driver";
const ADMIN_ID = "stripe_sandbox_admin";
const PRICING_VERSION = "STRIPE-SANDBOX-PRICING-001";
const PROMO_CODE = "STRIPE_SANDBOX_PROMO";
const TAX_CODE = "GST_STRIPE_SANDBOX";
const JURISDICTION = "QC";

const pickupStop: StopInput = {
  type: "pickup",
  address: {
    line1: "500 rue Sandbox",
    city: "Montréal",
    postal_code: "H1A1A1",
    lat: 45.5,
    lng: -73.6,
  },
};
const intermediateStop: StopInput = {
  type: "pickup",
  address: {
    line1: "550 rue Sandbox",
    city: "Montréal",
    postal_code: "H2A2A2",
    lat: 45.55,
    lng: -73.65,
  },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: {
    line1: "600 rue Sandbox",
    city: "Laval",
    postal_code: "H7A1A1",
    lat: 45.6,
    lng: -73.7,
  },
};
const stops = [pickupStop, intermediateStop, dropoffStop];

function authedRequest<T>(
  uid: string,
  role: string | undefined,
  data: T
): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: (role ? { role } : {}) as unknown as DecodedIdToken,
      rawToken: "sandbox-test-token",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function deleteQuery(query: FirebaseFirestore.Query): Promise<void> {
  const snap = await query.get();
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
}

async function cleanupFirestore(missionId: string | null): Promise<void> {
  if (missionId) {
    const missionRef = db.collection("delivery_requests").doc(missionId);
    const [stopsSnap, eventsSnap, paymentsSnap, snapshotsSnap] = await Promise.all([
      missionRef.collection("stops").get(),
      missionRef.collection("tracking_events").get(),
      db.collection("payments").where("mission_id", "==", missionId).get(),
      db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
    ]);
    const targetIds = [
      missionId,
      ...paymentsSnap.docs.map((doc) => doc.id),
      ...snapshotsSnap.docs.map((doc) => doc.id),
    ];
    await Promise.all([
      ...stopsSnap.docs.map((doc) => doc.ref.delete()),
      ...eventsSnap.docs.map((doc) => doc.ref.delete()),
      ...paymentsSnap.docs.map((doc) => doc.ref.delete()),
      ...snapshotsSnap.docs.map((doc) => doc.ref.delete()),
      ...targetIds.map((targetId) =>
        deleteQuery(db.collection("audit_logs").where("target_id", "==", targetId))
      ),
      db.collection("mission_financial_balance").doc(missionId).delete(),
      missionRef.delete(),
    ]);
  }

  await Promise.all([
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    db.collection("promo_codes").doc(PROMO_CODE).delete(),
    db.collection("tax_configs").doc(`${JURISDICTION}_${TAX_CODE}_current`).delete(),
  ]);
  for (let version = 1; version <= 5; version += 1) {
    await db
      .collection("tax_configs")
      .doc(`${JURISDICTION}_${TAX_CODE}_v${version}`)
      .delete();
  }
  await deleteQuery(db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID));
  await deleteQuery(
    db.collection("audit_logs").where("target_id", "==", `tax_configs/${JURISDICTION}/${TAX_CODE}`)
  );
}

describe("Stripe Sandbox — intégrité devis, mission, snapshot et autorisation", () => {
  const secretKey = (process.env.STRIPE_TEST_SECRET_KEY ?? "").trim();
  let stripe: Stripe;
  let provider: StripeProvider;
  let stripeCustomerId: string | null = null;
  let paymentIntentId: string | null = null;
  let missionId: string | null = null;

  beforeAll(async () => {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      throw new Error("Validation refusée : FIRESTORE_EMULATOR_HOST est absent.");
    }
    if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      throw new Error("Validation refusée : FIREBASE_AUTH_EMULATOR_HOST est absent.");
    }
    if (!secretKey.startsWith("sk_test_")) {
      throw new Error("Validation refusée : une clé Stripe sk_test_ est obligatoire.");
    }
    if (secretKey.startsWith("sk_live_")) {
      throw new Error("Validation refusée : une clé Stripe réelle ne peut jamais être utilisée.");
    }

    stripe = new Stripe(secretKey, { apiVersion: "2026-07-29.dahlia" });
    provider = new StripeProvider(secretKey, "");
    expect(provider.environment).toBe("test");
    setPaymentProviderForTesting(provider);

    const customer = await stripe.customers.create({
      email: "stripe-sandbox-validation@movi-k.invalid",
      name: "Movi-K automated sandbox validation",
      metadata: {
        movik_test: "quote_mission_payment_integrity",
        github_run_id: process.env.GITHUB_RUN_ID ?? "local",
      },
    });
    stripeCustomerId = customer.id;

    const paymentMethod = await stripe.paymentMethods.create({
      type: "card",
      card: { token: "tok_visa" },
      billing_details: { name: "Movi-K Sandbox Test" },
    });
    await stripe.paymentMethods.attach(paymentMethod.id, { customer: customer.id });

    await seedDefaultRuntimeFlagsEnabled();
    await db.collection("pricing_configs").doc("active").set({
      active_pricing_version: PRICING_VERSION,
    });
    await db.collection("pricing_versions").doc(PRICING_VERSION).set(
      buildPricingConfig({
        pricing_version: PRICING_VERSION,
        handling_fees: {
          loading_fee: 0,
          unloading_fee: 0,
          heavy_item_fee: 10,
          bulky_item_fee: 6,
          stairs_fee: 8,
          no_elevator_fee: 4,
          second_handler_fee: 15,
          special_equipment_fee: 7,
        },
        waiting_fee: { free_waiting_minutes: 10, waiting_rate_per_minute: 0.5 },
        additional_stop_fee: { fee_per_stop: 5 },
        surcharges: [
          { id: "sandbox_peak", mode: "percentage", value: 0.1, enabled: true },
        ],
        customer_service_fee: { service_fee_rate: 0.05, minimum_service_fee: 2 },
      })
    );
    await db.collection("promo_codes").doc(PROMO_CODE).set({
      is_active: true,
      discount_mode: "fixed_amount",
      discount_value: 7,
      max_discount_amount: 7,
      starts_at: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000),
      ends_at: admin.firestore.Timestamp.fromMillis(Date.now() + 3_600_000),
    });
    await updateTaxConfiguration.run(
      authedRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE,
        taxType: "gst",
        displayName: "TPS Stripe Sandbox (5%)",
        rate: 0.05,
        taxableComponents: ["transport", "platform_fees"],
        effectiveFromMillis: Date.now() - 10_000,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );
    await db.collection("driver_profiles").doc(DRIVER_ID).set({
      uid: DRIVER_ID,
      full_name: "Chauffeur Stripe Sandbox",
      city: "Montréal",
      status: "approved",
      service_radius_km: 25,
      accepted_vehicle_categories: ["cargoVan"],
      accepted_item_category_keys: ["furniture"],
      rating: 5,
      completed_missions: 10,
      created_at: admin.firestore.Timestamp.now(),
      approved_at: admin.firestore.Timestamp.now(),
      approved_by_user_id: ADMIN_ID,
      identity_verified: true,
      vehicle_verified: true,
      online_status: "online",
      documents_all_valid: true,
      stripe_connected_account_id: null,
    });
    await db.collection("payment_profiles").doc(CUSTOMER_ID).set({
      customer_id: CUSTOMER_ID,
      provider: "stripe",
      provider_customer_id: customer.id,
      default_payment_method_id: paymentMethod.id,
      created_at: admin.firestore.Timestamp.now(),
      updated_at: admin.firestore.Timestamp.now(),
    });
  });

  afterAll(async () => {
    try {
      if (paymentIntentId) {
        const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
        if (!["canceled", "succeeded"].includes(intent.status)) {
          await stripe.paymentIntents.cancel(paymentIntentId);
        }
      }
    } finally {
      setPaymentProviderForTesting(null);
      await cleanupFirestore(missionId);
      if (stripeCustomerId) {
        await stripe.customers.del(stripeCustomerId);
      }
    }
  });

  it("conserve exactement le total officiel jusqu'à l'autorisation Stripe en cents", async () => {
    const quoteResult = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, undefined, {
        vehicleCategory: "cargoVan",
        stops,
        distanceKm: 9999,
        estimatedDurationMinutes: 9999,
        handling: {
          isHeavyItem: true,
          isBulkyItem: true,
          needsStairs: true,
          noElevator: true,
          needsSecondHandler: true,
          needsSpecialEquipment: true,
        },
        totalWaitingMinutes: 20,
        additionalStopsCount: 999,
        applicableSurchargeIds: ["sandbox_peak"],
        promoCode: PROMO_CODE,
      })
    );
    const displayedTotalMinor = toMinorUnits(quoteResult.customerTotal);
    expect(displayedTotalMinor).toBeGreaterThan(0);
    expect(quoteResult.breakdown.handlingFeesTotal).toBeGreaterThan(0);
    expect(quoteResult.breakdown.waitingFee).toBeGreaterThan(0);
    expect(quoteResult.breakdown.additionalStopsFee).toBeGreaterThan(0);
    expect(quoteResult.breakdown.surchargesTotal).toBeGreaterThan(0);
    expect(quoteResult.breakdown.customerDiscountAmount).toBeGreaterThan(0);
    expect(quoteResult.breakdown.taxAmount).toBeGreaterThan(0);

    const created = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, undefined, {
        quoteId: quoteResult.quoteId,
        itemCategoryKey: "furniture",
        description: "Validation Stripe Sandbox de l'intégrité financière.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 1,
        estimatedDurationMinutes: 1,
        stops,
        customerDisplayName: "Client Stripe Sandbox",
      })
    );
    missionId = created.missionId;
    if (!missionId) {
      throw new Error("Mission creation did not return a missionId.");
    }

    const accepted = await acceptDelivery.run(
      authedRequest<AcceptDeliveryRequest>(DRIVER_ID, undefined, { missionId })
    );
    expect(accepted.success).toBe(true);

    const missionSnap = await db.collection("delivery_requests").doc(missionId).get();
    const mission = missionSnap.data()!;
    const quoteSnap = await db.collection("delivery_quotes").doc(quoteResult.quoteId).get();
    const quote = quoteSnap.data()!;
    const snapshotSnap = await db
      .collection("financial_snapshots")
      .doc(mission.active_financial_snapshot_id as string)
      .get();
    const snapshot = snapshotSnap.data()!;
    const paymentSnap = await db
      .collection("payments")
      .doc(mission.active_payment_id as string)
      .get();
    const payment = paymentSnap.data()!;
    paymentIntentId = payment.provider_payment_intent_id as string;

    expect(quote.customer_total_minor).toBe(displayedTotalMinor);
    expect(mission.customer_total_minor).toBe(displayedTotalMinor);
    expect(snapshot.customer_total_minor).toBe(displayedTotalMinor);
    expect(payment.amount_requested_minor).toBe(displayedTotalMinor);
    expect(payment.amount_authorized_minor).toBe(displayedTotalMinor);
    expect(payment.stripe_environment).toBe("test");
    expect(mission.quote_integrity_hash).toBe(quote.integrity_hash);
    expect(snapshot.quote_integrity_hash).toBe(quote.integrity_hash);

    const stripeStatus = await provider.getPaymentStatus(paymentIntentId);
    expect(stripeStatus.status).toBe("requires_capture");
    expect(stripeStatus.amountAuthorizedMinor).toBe(displayedTotalMinor);
    expect(stripeStatus.amountCapturedMinor).toBe(0);

    const rawIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    expect(rawIntent.livemode).toBe(false);
    expect(rawIntent.amount).toBe(displayedTotalMinor);
    expect(rawIntent.capture_method).toBe("manual");
    expect(rawIntent.metadata.movik_mission_id).toBe(missionId);

    const cancelled = await provider.cancelAuthorization({
      providerPaymentIntentId: paymentIntentId,
      idempotencyKey: `stripe-sandbox-cancel-${process.env.GITHUB_RUN_ID ?? "local"}`,
    });
    expect(cancelled.success).toBe(true);
    expect(cancelled.status).toBe("canceled");
  });
});
