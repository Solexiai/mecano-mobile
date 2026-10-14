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
export const startBookingCardSetup = onCall(options, async request => {
  const ctx = requireSignedIn(request); const id = quoteId(request.data.quoteId);
  const policy = await getBookingPolicy();
  if (!policy?.setup_enabled || request.data.termsVersion !== policy.version || request.data.accepted !== true) throw failedPrecondition('Acceptez les conditions applicables avant l’enregistrement de la carte.');
  if (request.auth?.token.email_verified !== true) throw failedPrecondition('Vérifiez votre adresse courriel.');
  const quote = (await db.doc(`delivery_quotes/${id}`).get()).data();
  if (!quote || quote.customer_id !== ctx.uid) throw permissionDenied('Devis inaccessible.');
  const locked = resolveLockedQuote(id, quote);
  if (!locked.pricingSnapshot?.booking || quote.is_consumed || quote.status === 'cancelled' || quote.expires_at.toMillis() <= Date.now()) throw failedPrecondition('Recalculez le devis avant d’enregistrer votre carte.');
  const provider = getPaymentProvider();
  const profileRef = db.doc(`payment_profiles/${ctx.uid}`);
  let profile = (await profileRef.get()).data();
  if (!profile) {
    const user = await authAdmin.getUser(ctx.uid);
    const customer = await provider.createCustomer({ userId: ctx.uid, email: user.email ?? `${ctx.uid}@no-email.movik.ca`, displayName: user.displayName ?? 'Client Movi-K' });
    profile = await db.runTransaction(async tx => {
      const current = (await tx.get(profileRef)).data(); if (current) return current;
      const created = { customer_id: ctx.uid, provider: 'stripe', provider_customer_id: customer.providerCustomerId,
        default_payment_method_id: null, stripe_environment: provider.environment,
        created_at: admin.firestore.Timestamp.now(), updated_at: admin.firestore.Timestamp.now() };
      tx.set(profileRef, created); return created;
    });
  }
  if (profile.stripe_environment !== provider.environment) throw failedPrecondition('Le profil de paiement appartient à un autre environnement.');
  if (profile.default_payment_method_id && request.data.replace !== true) return { ready: true, url: null };
  const ref = db.doc(`booking_payment_setups/${id}`);
  const saved: FirebaseFirestore.DocumentData = await db.runTransaction(async tx => {
    const old = (await tx.get(ref)).data(); if (old) return old;
    const locale = ['fr','en','es'].includes(request.data.locale) ? request.data.locale : 'fr';
    const base = new URL(APP_PUBLIC_BASE_URL.value());
    if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash) throw failedPrecondition('Le domaine de retour de paiement doit être configuré en HTTPS.');
    const row = { user_id: ctx.uid, quote_id: id, customer_id: profile!.provider_customer_id,
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
