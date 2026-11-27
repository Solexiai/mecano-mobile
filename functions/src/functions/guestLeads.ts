// -----------------------------------------------------------------------------
// guestLeads.ts — prix avec le courriel seulement (voir lib/guestLead.ts).
//
//   - registerQuoteLead (session anonyme) : range le courriel tapé à l'étape
//     du prix dans `users/{uid}` (`guest: true`). Rien d'autre n'est créé.
//   - completeGuestAccount (compte avec courriel) : après le choix du mot de
//     passe, la fiche devient celle d'un client ordinaire. Le courriel vient
//     du jeton de connexion, jamais du client.
//     Si cet appel se perd, le serveur refait le passage à l'étape de la
//     carte (lib/guestProfile.ts).
// -----------------------------------------------------------------------------
import { createHash } from "crypto";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import {
  GUEST_EMAIL_MAX_CHANGES,
  GUEST_LEADS_PER_IP_PER_DAY,
  isAnonymousToken,
  normalizeLeadEmail,
} from "../lib/guestLead";
import { cleanFullName, settleGuestProfile } from "../lib/guestProfile";
import { nextDailyRoutingBudget, RoutingBudget } from "../lib/routingRateLimit";
import { refuseDriverAsCustomer } from "../lib/userKind";
import { visitorIp } from "./estimateDeliveryPrice";

const TOO_MANY = "Trop de demandes. Réessayez plus tard.";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function handleRegisterQuoteLead(request: CallableRequest<any>): Promise<{ saved: boolean; reason?: string }> {
  const ctx = requireSignedIn(request);
  refuseDriverAsCustomer(ctx.roles);
  // Un vrai compte a déjà son courriel : rien à ranger.
  if (!isAnonymousToken(request.auth?.token as Record<string, unknown> | undefined)) {
    return { saved: false, reason: "account" };
  }
  const email = normalizeLeadEmail(request.data?.email);
  if (!email) throw invalidArgument("Adresse courriel invalide.");
  const locale = request.data?.locale === "en" || request.data?.locale === "es" ? request.data.locale : "fr";

  const now = Date.now();
  const ipHash = createHash("sha256").update(`guest_lead:${visitorIp(request)}`).digest("hex");
  const ipRef = db.collection("routing_request_limits").doc(`guest_lead_${ipHash}`);
  const userRef = db.collection("users").doc(ctx.uid);
  await db.runTransaction(async (tx) => {
    const [userSnap, ipSnap] = await Promise.all([tx.get(userRef), tx.get(ipRef)]);
    const existing = userSnap.data();
    // Jamais par-dessus une vraie fiche.
    if (existing && existing.guest !== true) throw failedPrecondition("Ce compte existe déjà.");
    if (existing?.email === email) return;
    const changes = Number.isSafeInteger(existing?.guest_email_changes) ? (existing!.guest_email_changes as number) : 0;
    if (changes >= GUEST_EMAIL_MAX_CHANGES) throw new HttpsError("resource-exhausted", TOO_MANY);
    const daily = nextDailyRoutingBudget(
      (ipSnap.data() as { daily?: RoutingBudget } | undefined)?.daily, now, GUEST_LEADS_PER_IP_PER_DAY
    );
    if (!daily.allowed) throw new HttpsError("resource-exhausted", TOO_MANY);
    tx.set(ipRef, { daily: daily.next });
    tx.set(userRef, {
      uid: ctx.uid,
      email,
      roles: ["customer"],
      guest: true,
      guest_email_changes: changes + 1,
      created_at: existing?.created_at ?? new Date(now).toISOString(),
      is_disabled: false,
      email_verified: false,
      preferred_locale: locale,
      updated_at: admin.firestore.Timestamp.fromMillis(now),
    }, { merge: true });
  });
  return { saved: true };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function handleCompleteGuestAccount(request: CallableRequest<any>): Promise<{ completed: boolean }> {
  const ctx = requireSignedIn(request);
  if (isAnonymousToken(request.auth?.token as Record<string, unknown> | undefined) || !ctx.email) {
    throw failedPrecondition("Choisissez d'abord votre mot de passe.");
  }
  const completed = await settleGuestProfile(ctx.uid, ctx.email, cleanFullName(request.data?.fullName));
  return { completed };
}

export const registerQuoteLead = onCall(handleRegisterQuoteLead);
export const completeGuestAccount = onCall(handleCompleteGuestAccount);
