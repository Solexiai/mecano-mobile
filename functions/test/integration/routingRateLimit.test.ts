// Emulator-only, non-destructive tests. Unique UIDs avoid fixture collisions;
// no cleanup/delete requests are issued. The ephemeral emulator owns the data.
import { createHash, randomUUID } from "crypto";
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { db } from "../../src/lib/admin";
import { consumeRoutingBudget } from "../../src/lib/routingRateLimit";
import { calculateRoute, calculateAuthoritativeRoute } from "../../src/functions/calculateRoute";
import { calculateDeliveryQuote } from "../../src/functions/calculateDeliveryQuote";

process.env.ROUTING_REQUESTS_PER_WINDOW = "3";
process.env.ROUTING_WINDOW_SECONDS = "60";
const freshUid = () => `phase8-quota-${randomUUID()}`;
const refFor = (uid: string) => db.collection("routing_request_limits").doc(createHash("sha256").update(uid).digest("hex"));
function request<T>(uid: string, data: T): CallableRequest<T> {
  return { data, auth: { uid, token: {} as DecodedIdToken, rawToken: "emulator-only" }, rawRequest: {} as Request, acceptsStreaming: false };
}
const routeInput = { pickupLat: 45.5, pickupLng: -73.6, dropoffLat: 45.6, dropoffLng: -73.7 };

test("concurrent requests cannot overspend the shared budget", async () => {
  const uid = freshUid();
  const results = await Promise.allSettled(Array.from({ length: 10 }, () => consumeRoutingBudget(uid)));
  expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(3);
  expect((await refFor(uid).get()).data()?.count).toBe(3);
  for (const r of results) if (r.status === "rejected") expect(r.reason.code).toBe("resource-exhausted");
});
test("public route consumes once; internal authoritative route never charges twice", async () => {
  const uid = freshUid();
  await calculateRoute.run(request(uid, routeInput));
  expect((await refFor(uid).get()).data()?.count).toBe(1);
  await calculateAuthoritativeRoute(routeInput);
  expect((await refFor(uid).get()).data()?.count).toBe(1);
  await consumeRoutingBudget(uid);
  await calculateRoute.run(request(uid, routeInput));
  await expect(calculateRoute.run(request(uid, routeInput))).rejects.toMatchObject({ code: "resource-exhausted" });
});
test("different customers have separate budgets and no raw UID in the record", async () => {
  const a = freshUid(); const b = freshUid();
  for (let i = 0; i < 3; i++) await consumeRoutingBudget(a);
  await expect(consumeRoutingBudget(b)).resolves.toBeUndefined();
  expect((await refFor(b).get()).data()).toEqual({ startedAtMs: expect.any(Number), count: 1 });
});
test("unauthenticated callers cannot create budget records", async () => {
  const uid = freshUid();
  const req = request(uid, routeInput); req.auth = undefined;
  await expect(calculateRoute.run(req)).rejects.toMatchObject({ code: "unauthenticated" });
  const quoteReq = request(uid, { vehicleCategory: "cargoVan" }); quoteReq.auth = undefined;
  await expect(calculateDeliveryQuote.run(quoteReq)).rejects.toMatchObject({ code: "unauthenticated" });
  expect((await refFor(uid).get()).exists).toBe(false);
});
