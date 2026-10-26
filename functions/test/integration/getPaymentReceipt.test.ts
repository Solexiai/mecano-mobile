// -----------------------------------------------------------------------------
// getPaymentReceipt — reçu Stripe d'une livraison (2026-10-26). Lecture
// seule : seul le client de la mission obtient le lien, et seulement pour un
// montant réellement débité.
// -----------------------------------------------------------------------------
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { getPaymentReceipt, GetPaymentReceiptRequest } from "../../src/functions/getPaymentReceipt";
import { admin, db } from "../../src/lib/admin";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";

const MISSION = "receipt_mission_001";
const CUSTOMER = "receipt_customer_a";
const OTHER = "receipt_customer_b";

function req(uid: string, data: unknown): CallableRequest<GetPaymentReceiptRequest> {
  return {
    data: data as GetPaymentReceiptRequest,
    auth: { uid, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seed(status: string, chargeId: string | null): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION).set({
    customer_id: CUSTOMER, driver_id: "receipt_driver", status: "completed",
    created_at: admin.firestore.Timestamp.now(),
  });
  await db.collection("payments").doc(`${MISSION}_pay`).set({
    payment_id: `${MISSION}_pay`, mission_id: MISSION, customer_id: CUSTOMER,
    driver_id: "receipt_driver", status, currency: "CAD",
    amount_authorized_minor: 2500, amount_captured_minor: chargeId ? 2500 : 0,
    amount_refunded_minor: 0, application_fee_minor: 375, provider: "stripe",
    provider_charge_id: chargeId, stripe_environment: "test",
    captured_at: chargeId ? admin.firestore.Timestamp.now() : null,
    created_at: admin.firestore.Timestamp.now(), updated_at: admin.firestore.Timestamp.now(),
  });
}

let provider: FakePaymentProvider;
beforeEach(() => {
  provider = new FakePaymentProvider();
  setPaymentProviderForTesting(provider);
});
afterEach(async () => {
  setPaymentProviderForTesting(null);
  await db.collection("payments").doc(`${MISSION}_pay`).delete();
  await db.collection("delivery_requests").doc(MISSION).delete();
});

it("le client obtient le lien du reçu Stripe du montant débité, sans rien modifier", async () => {
  await seed("captured", "ch_fake_001");
  const before = (await db.collection("payments").doc(`${MISSION}_pay`).get()).data();
  const result = await getPaymentReceipt.run(req(CUSTOMER, { missionId: MISSION }));
  expect(result).toEqual({ url: "https://pay.stripe.test/receipts/ch_fake_001" });
  expect(provider.receiptLookups).toEqual(["ch_fake_001"]);
  expect((await db.collection("payments").doc(`${MISSION}_pay`).get()).data()).toEqual(before);
  expect(provider.capturedPaymentParams).toHaveLength(0);
});

it("un autre client ne peut pas obtenir ce reçu", async () => {
  await seed("captured", "ch_fake_001");
  await expect(getPaymentReceipt.run(req(OTHER, { missionId: MISSION })))
    .rejects.toMatchObject({ code: "permission-denied" });
  expect(provider.receiptLookups).toHaveLength(0);
});

it.each(["authorized", "cancelled", "failed"])("rien de débité (%s) : pas de reçu", async (status) => {
  await seed(status, null);
  await expect(getPaymentReceipt.run(req(CUSTOMER, { missionId: MISSION })))
    .rejects.toMatchObject({ code: "failed-precondition" });
  expect(provider.receiptLookups).toHaveLength(0);
});

it.each([undefined, "", "../x", 42])("missionId invalide (%p) refusé", async (missionId) => {
  await expect(getPaymentReceipt.run(req(CUSTOMER, { missionId })))
    .rejects.toMatchObject({ code: "invalid-argument" });
});
