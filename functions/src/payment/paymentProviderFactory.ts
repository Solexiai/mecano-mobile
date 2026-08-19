// -----------------------------------------------------------------------------
// paymentProviderFactory.ts — Point d'accès UNIQUE au PaymentProvider actif.
//
// Toutes les Cloud Functions Phase 6 doivent obtenir leur PaymentProvider
// via `getPaymentProvider()`, jamais en instanciant StripeProvider
// directement. Garantit un seul endroit où la clé secrète est lue.
// -----------------------------------------------------------------------------

import { NotConfiguredPaymentProvider, PaymentProvider } from "./paymentProvider";
import { StripeProvider } from "./stripeProvider";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";

// -----------------------------------------------------------------------------
// Point d'injection RÉSERVÉ AUX TESTS AUTOMATISÉS (jamais utilisé en
// production — aucun chemin de code de production n'appelle
// `setPaymentProviderForTesting`). Permet aux tests d'intégration
// (`test/integration/*.test.ts`, exécutés contre l'émulateur Firestore/Auth,
// qui ne dispose d'aucune vraie clé Stripe) d'injecter un
// `FakePaymentProvider` déterministe pour vérifier l'ORCHESTRATION
// (transactions, machine d'état, ledger) sans jamais appeler le réseau
// Stripe réel. `getPaymentProvider()` continue, par défaut, de renvoyer
// `NotConfiguredPaymentProvider` tant qu'aucun override n'a été positionné —
// le comportement de production (fail-fast si STRIPE_SECRET_KEY absent)
// n'est jamais modifié par l'existence de ce mécanisme.
// -----------------------------------------------------------------------------
let testOverrideProvider: PaymentProvider | null = null;

export function setPaymentProviderForTesting(provider: PaymentProvider | null): void {
  testOverrideProvider = provider;
}

export function getPaymentProvider(): PaymentProvider {
  if (testOverrideProvider) {
    return testOverrideProvider;
  }

  let secretKey = "";
  let webhookSecret = "";
  try {
    secretKey = STRIPE_SECRET_KEY.value();
    webhookSecret = STRIPE_WEBHOOK_SECRET.value();
  } catch {
    secretKey = "";
  }

  if (!secretKey) {
    return new NotConfiguredPaymentProvider();
  }
  return new StripeProvider(secretKey, webhookSecret);
}
