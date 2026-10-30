import { requireBookingConsent } from '../lib/bookingContract';
import { onCall } from 'firebase-functions/v2/https';
import { admin, authAdmin, db } from '../lib/admin';
import { requireSignedIn } from '../lib/auth';
import { failedPrecondition, invalidArgument, permissionDenied } from '../lib/errors';
import { getPaymentProvider } from '../payment/paymentProviderFactory';
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from '../lib/secrets';
import { APP_PUBLIC_BASE_URL } from '../lib/appConfig';
import { getBookingPolicy } from '../lib/bookingServer';
import { verifyCardSetup } from '../lib/bookingPayment';
import { resolveLockedQuote } from '../lib/quoteIntegrity';

const options = { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] };
function quoteId(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(value)) throw invalidArgument('Devis invalide.');
  return value;
}
/**
 * The customer's payment profile in the ACTIVE Stripe environment. Passage au
 * vrai argent (2026-10-30): a profile of another environment (a test
 * customer once live is active) is archived under `archived/` and a new
 * Stripe customer is created; the customer simply enters a card again. The
 * old profile is never reused (fail closed, see stripeEnvironment.ts).
 */
async function ensurePaymentProfile(uid: string, provider: ReturnType<typeof getPaymentProvider>): Promise<FirebaseFirestore.DocumentData> {
  const profileRef = db.doc(`payment_profiles/${uid}`);
  const existing = (await profileRef.get()).data();
  if (existing && existing.stripe_environment === provider.environment) return existing;
  const user = await authAdmin.getUser(uid);
  const customer = await provider.createCustomer({ userId: uid, email: user.email ?? `${uid}@no-email.movik.ca`, displayName: user.displayName ?? 'Client Movi-K' });
  return db.runTransaction(async tx => {
    const current = (await tx.get(profileRef)).data();
    if (current && current.stripe_environment === provider.environment) return current;
    const now = admin.firestore.Timestamp.now();
    if (current) {
      tx.set(profileRef.collection('archived').doc(`${current.stripe_environment ?? 'untagged'}_${now.toMillis()}`),
        { ...current, archived_at: now, archived_reason: 'stripe_environment_changed', archived_from_environment: current.stripe_environment ?? null });
    }
    const created = { customer_id: uid, provider: 'stripe', provider_customer_id: customer.providerCustomerId,
      default_payment_method_id: null, stripe_environment: provider.environment,
      created_at: now, updated_at: now };
    tx.set(profileRef, created); return created;
  });
}

export const startBookingCardSetup = onCall(options, async request => {
  const ctx = requireSignedIn(request); const id = quoteId(request.data.quoteId);
  const policy = await getBookingPolicy();
  requireBookingConsent(policy, request.data.consent);
  if (!policy.setup_enabled) throw failedPrecondition('Acceptez les conditions applicables avant l’enregistrement de la carte.');
  if (request.auth?.token.email_verified !== true) throw failedPrecondition('Vérifiez votre adresse courriel.');
  const quote = (await db.doc(`delivery_quotes/${id}`).get()).data();
  if (!quote || quote.customer_id !== ctx.uid) throw permissionDenied('Devis inaccessible.');
  const locked = resolveLockedQuote(id, quote);
  // Price-before-assignment quotes are commercial bookings judged by drivers
  // (owner decision 2026-10-22); the card is only authorized at acceptance.
  if (!(locked.pricingSnapshot?.booking || locked.pricingSnapshot?.pre_assignment) || quote.is_consumed || quote.status === 'cancelled' || quote.expires_at.toMillis() <= Date.now()) throw failedPrecondition('Recalculez le devis avant d’enregistrer votre carte.');
  const provider = getPaymentProvider();
  const profile = await ensurePaymentProfile(ctx.uid, provider);
  if (profile.stripe_environment !== provider.environment) throw failedPrecondition('Le profil de paiement appartient à un autre environnement.');
  if (profile.default_payment_method_id && request.data.replace !== true) return { ready: true, url: null };
  const ref = db.doc(`booking_payment_setups/${id}`);
  const saved: FirebaseFirestore.DocumentData = await db.runTransaction(async tx => {
    const old = (await tx.get(ref)).data(); if (old) return old;
    const locale = ['fr','en','es'].includes(request.data.locale) ? request.data.locale : 'fr';
    const base = new URL(APP_PUBLIC_BASE_URL.value());
    if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash) throw failedPrecondition('Le domaine de retour de paiement doit être configuré en HTTPS.');
    const row = { user_id: ctx.uid, quote_id: id, customer_id: profile.provider_customer_id,
      stripe_environment: provider.environment, locale,
      return_url: `${base.origin}/${locale}/livraison/demande`, created_at: admin.firestore.Timestamp.now() };
    tx.create(ref, row); return row;
  });
  if (saved.user_id !== ctx.uid || saved.stripe_environment !== provider.environment || saved.customer_id !== profile.provider_customer_id) throw permissionDenied('Session inaccessible.');
  const setup = saved.session_id ? await provider.getCardSetup(saved.session_id) : await provider.createCardSetup({
    customerId: saved.customer_id, userId: ctx.uid, quoteId: id, returnUrl: saved.return_url, locale: saved.locale });
  await ref.set({ session_id: setup.id }, { merge: true });
  const method = verifyCardSetup(setup, { customerId: saved.customer_id, userId: ctx.uid, quoteId: id, environment: provider.environment });
  if (method) { await completeSavedSetup(id); return { ready: true, url: null }; }
  if (!setup.url) throw failedPrecondition('La session Stripe a expiré. Recalculez le devis pour recommencer.');
  return { ready: false, url: setup.url };
});

export async function completeSavedSetup(id: string): Promise<boolean> {
  const ref = db.doc(`booking_payment_setups/${id}`); const saved = (await ref.get()).data();
  if (!saved?.session_id) return false;
  const provider = getPaymentProvider();
  if (saved.stripe_environment !== provider.environment) throw failedPrecondition('Environnement de paiement incompatible.');
  const setup = await provider.getCardSetup(saved.session_id);
  const method = verifyCardSetup(setup, { customerId: saved.customer_id, userId: saved.user_id, quoteId: id, environment: provider.environment });
  if (!method) return false;
  await db.runTransaction(async tx => {
    const profileRef = db.doc(`payment_profiles/${saved.user_id}`); const profile = (await tx.get(profileRef)).data();
    const current = (await tx.get(ref)).data();
    if (current?.completed_at) return;
    if (profile?.provider_customer_id !== saved.customer_id || profile?.stripe_environment !== provider.environment) throw failedPrecondition('Profil de paiement incompatible.');
    tx.update(profileRef, { default_payment_method_id: method, updated_at: admin.firestore.Timestamp.now() });
    tx.update(ref, { completed_at: admin.firestore.Timestamp.now() });
  });
  return true;
}
export const getBookingCardStatus = onCall(options, async request => {
  const { uid } = requireSignedIn(request); const id = quoteId(request.data.quoteId);
  const quote = (await db.doc(`delivery_quotes/${id}`).get()).data();
  if (!quote || quote.customer_id !== uid) throw permissionDenied('Devis inaccessible.');
  await completeSavedSetup(id);
  const profile = (await db.doc(`payment_profiles/${uid}`).get()).data();
  return { ready: !!profile?.default_payment_method_id && profile.stripe_environment === getPaymentProvider().environment };
});
