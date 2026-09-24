// One shared budget for public route and quote callables; internal route calls
// are NOT charged a second time. A single document per UID bounds storage growth.
import { createHash } from "crypto";
import { HttpsError } from "firebase-functions/v2/https";
import { warn } from "firebase-functions/logger";
import { db } from "./admin";
import { ROUTING_REQUESTS_PER_WINDOW, ROUTING_WINDOW_SECONDS } from "./appConfig";

export interface RoutingBudget { startedAtMs: number; count: number }
export type BudgetDecision =
  | { allowed: true; next: RoutingBudget }
  | { allowed: false; retryAfterSeconds: number };

export function nextRoutingBudget(
  stored: RoutingBudget | undefined, now: number, limit: number, windowMs: number
): BudgetDecision {
  if (!Number.isSafeInteger(now) || now < 0 || !Number.isInteger(limit) ||
      limit < 1 || limit > 10000 || !Number.isSafeInteger(windowMs) ||
      windowMs < 1000 || windowMs > 3600000) {
    throw new HttpsError("failed-precondition", "Configuration de protection invalide.");
  }
  if (stored && (!Number.isSafeInteger(stored.startedAtMs) || stored.startedAtMs < 0 ||
      stored.startedAtMs > now || !Number.isSafeInteger(stored.count) || stored.count < 1)) {
    throw new HttpsError("unavailable", "Vérification temporairement indisponible.");
  }
  const active = stored && now - stored.startedAtMs < windowMs;
  const budget = active ? stored : { startedAtMs: now, count: 0 };
  if (budget.count >= limit) {
    return { allowed: false, retryAfterSeconds: Math.ceil((budget.startedAtMs + windowMs - now) / 1000) };
  }
  return { allowed: true, next: { startedAtMs: budget.startedAtMs, count: budget.count + 1 } };
}

export async function consumeRoutingBudget(uid: string): Promise<void> {
  const id = createHash("sha256").update(uid).digest("hex");
  const ref = db.collection("routing_request_limits").doc(id);
  let decision: BudgetDecision;
  try {
    decision = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const result = nextRoutingBudget(
        snap.exists ? snap.data() as RoutingBudget : undefined,
        Date.now(), ROUTING_REQUESTS_PER_WINDOW.value(), ROUTING_WINDOW_SECONDS.value() * 1000
      );
      if (result.allowed) tx.set(ref, result.next);
      return result;
    });
  } catch (error) {
    warn("routing_budget_check_failed", { operation: "route_quote" });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("unavailable", "Vérification temporairement indisponible.");
  }
  if (!decision.allowed) {
    warn("routing_budget_exhausted", { operation: "route_quote", retryAfterSeconds: decision.retryAfterSeconds });
    throw new HttpsError("resource-exhausted", "Trop de demandes rapprochées. Réessayez dans un moment.", { retryAfterSeconds: decision.retryAfterSeconds });
  }
}
