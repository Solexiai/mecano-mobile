import { nextRoutingBudget } from "../../src/lib/routingRateLimit";

const now = 1_800_000_000_000;
describe("shared routing quota policy", () => {
  test("starts a fresh budget", () => {
    expect(nextRoutingBudget(undefined, now, 2, 60000)).toEqual({ allowed: true, next: { startedAtMs: now, count: 1 } });
  });
  test("increments within the same window", () => {
    expect(nextRoutingBudget({ startedAtMs: now, count: 1 }, now + 1000, 2, 60000)).toEqual({ allowed: true, next: { startedAtMs: now, count: 2 } });
  });
  test("rejects at the limit with bounded retry time", () => {
    expect(nextRoutingBudget({ startedAtMs: now, count: 2 }, now + 1500, 2, 60000)).toEqual({ allowed: false, retryAfterSeconds: 59 });
  });
  test("reuses the same budget at the exact next-window boundary", () => {
    expect(nextRoutingBudget({ startedAtMs: now, count: 2 }, now + 60000, 2, 60000)).toEqual({ allowed: true, next: { startedAtMs: now + 60000, count: 1 } });
  });
  test.each([0, -1, NaN, Infinity, 1.5, 10001])("fails closed for invalid limit %s", (limit) => {
    expect(() => nextRoutingBudget(undefined, now, limit, 60000)).toThrow("Configuration");
  });
  test.each([0, 999, NaN, Infinity, 3600001])("fails closed for invalid window %s", (window) => {
    expect(() => nextRoutingBudget(undefined, now, 2, window)).toThrow("Configuration");
  });
  test.each([0, -1, 1.2, NaN])("fails closed for a corrupt count %s", (count) => {
    expect(() => nextRoutingBudget({ startedAtMs: now, count }, now, 2, 60000)).toThrow("indisponible");
  });
  test("does not grant a free window when the stored clock is in the future", () => {
    expect(() => nextRoutingBudget({ startedAtMs: now + 1, count: 1 }, now, 2, 60000)).toThrow("indisponible");
  });
  test("a lowered quota does not reset existing consumption", () => {
    expect(nextRoutingBudget({ startedAtMs: now, count: 9 }, now, 2, 60000).allowed).toBe(false);
  });
});
