// ---------------------------------------------------------------------------
// Tests unitaires — stripeEnvironment.ts (Phase 8B, item f, garde-fou
// d'isolation d'environnement TEST/LIVE).
//
// Aucun émulateur requis : imports directs depuis
// `../../src/lib/stripeEnvironment`, pur Jest.
//
// Couvre :
//   - resolveStripeEnvironmentFromSecretKey() : les 4 préfixes reconnus
//     (sk_test_/rk_test_/sk_live_/rk_live_) + rejet fail-closed d'un préfixe
//     inconnu.
//   - assertStripeReferenceEnvironmentConsistency() : la table de vérité
//     fail-closed complète (test/test OK, live/live OK, test/live BLOCK,
//     live/test BLOCK, absent+test toléré, absent+live BLOCK).
//   - assertStripeReferenceEnvironmentConsistencyOrLog() : même
//     comportement, avec vérification que l'échec est bien journalisé
//     (BLOC I) avant d'être re-levé.
// ---------------------------------------------------------------------------

import {
  assertStripeReferenceEnvironmentConsistency,
  assertStripeReferenceEnvironmentConsistencyOrLog,
  resolveStripeEnvironmentFromSecretKey,
  STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE,
  stripeEnvironmentMismatchError,
  StripeEnvironment,
} from "../../src/lib/stripeEnvironment";
import * as observability from "../../src/lib/observability";

describe("resolveStripeEnvironmentFromSecretKey — dérivation depuis le préfixe de clé", () => {
  it("sk_test_... -> environment 'test'", () => {
    expect(resolveStripeEnvironmentFromSecretKey("sk_test_abc123")).toBe("test");
  });

  it("rk_test_... -> environment 'test' (clé restreinte, même préfixe reconnu)", () => {
    expect(resolveStripeEnvironmentFromSecretKey("rk_test_abc123")).toBe("test");
  });

  it("sk_live_... -> environment 'live'", () => {
    expect(resolveStripeEnvironmentFromSecretKey("sk_live_abc123")).toBe("live");
  });

  it("rk_live_... -> environment 'live' (clé restreinte, même préfixe reconnu)", () => {
    expect(resolveStripeEnvironmentFromSecretKey("rk_live_abc123")).toBe("live");
  });

  it("préfixe totalement inconnu -> fail closed (lève, ne devine jamais un défaut)", () => {
    expect(() => resolveStripeEnvironmentFromSecretKey("not_a_stripe_key")).toThrow();
  });

  it("préfixe vide -> fail closed", () => {
    expect(() => resolveStripeEnvironmentFromSecretKey("")).toThrow();
  });

  it("préfixe partiel/tronqué ('sk_' seul, ni test ni live) -> fail closed", () => {
    expect(() => resolveStripeEnvironmentFromSecretKey("sk_")).toThrow();
  });

  it("préfixe non reconnu ne devine JAMAIS 'test' par défaut (vérifié explicitement)", () => {
    let thrown: Error | null = null;
    try {
      resolveStripeEnvironmentFromSecretKey("pk_test_should_not_be_a_secret_key");
    } catch (err) {
      thrown = err as Error;
    }
    expect(thrown).not.toBeNull();
    // pk_ (clé PUBLIQUE) n'est jamais un préfixe de clé SECRÈTE valide ici.
  });
});

describe("assertStripeReferenceEnvironmentConsistency — table de vérité fail-closed", () => {
  it("stored='test' + active='test' -> OK (ne lève rien)", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "test",
        storedEnvironment: "test",
      })
    ).not.toThrow();
  });

  it("stored='live' + active='live' -> OK (ne lève rien)", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "live",
        storedEnvironment: "live",
      })
    ).not.toThrow();
  });

  it("stored='test' + active='live' -> BLOCK (référence test réutilisée en live)", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "live",
        storedEnvironment: "test",
      })
    ).toThrow();
  });

  it("stored='live' + active='test' -> BLOCK (référence live réutilisée en test)", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "test",
        storedEnvironment: "live",
      })
    ).toThrow();
  });

  it(
    "stored=absent (undefined) + active='test' -> TOLÉRÉ (comportement historique " +
      "fail-safe explicite : données pré-migration/fixtures de test, jamais de fonds réels)",
    () => {
      expect(() =>
        assertStripeReferenceEnvironmentConsistency({
          activeEnvironment: "test",
          storedEnvironment: undefined,
        })
      ).not.toThrow();
    }
  );

  it("stored=null (absent) + active='test' -> TOLÉRÉ (même règle, valeur null explicite)", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "test",
        storedEnvironment: null,
      })
    ).not.toThrow();
  });

  it(
    "stored=absent (undefined) + active='live' -> BLOCK (fail closed : aucune donnée " +
      "non taguée ne peut être présumée sûre à l'ère de l'argent réel)",
    () => {
      expect(() =>
        assertStripeReferenceEnvironmentConsistency({
          activeEnvironment: "live",
          storedEnvironment: undefined,
        })
      ).toThrow();
    }
  );

  it("stored=null (absent) + active='live' -> BLOCK (même règle, valeur null explicite)", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "live",
        storedEnvironment: null,
      })
    ).toThrow();
  });

  it("l'erreur levée est toujours celle produite par stripeEnvironmentMismatchError() (message générique, jamais de détail interne)", () => {
    let thrown: Error | null = null;
    try {
      assertStripeReferenceEnvironmentConsistency({
        activeEnvironment: "live",
        storedEnvironment: "test",
      });
    } catch (err) {
      thrown = err as Error;
    }
    expect(thrown).not.toBeNull();
    expect(thrown!.message).toBe(stripeEnvironmentMismatchError().message);
    // Le message ne doit JAMAIS exposer "test"/"live"/l'ID de référence au client.
    expect(thrown!.message).not.toMatch(/test|live/i);
  });

  it("exhaustivité de la table de vérité — toutes les combinaisons StripeEnvironment x (StripeEnvironment|null|undefined)", () => {
    const environments: StripeEnvironment[] = ["test", "live"];
    const storedValues: (StripeEnvironment | null | undefined)[] = ["test", "live", null, undefined];
    const expectedBlock = new Set([
      "live:test",
      "test:live",
      "live:undefined",
      "live:null",
    ]);
    for (const active of environments) {
      for (const stored of storedValues) {
        const key = `${active}:${stored}`;
        const shouldBlock = expectedBlock.has(key);
        if (shouldBlock) {
          expect(() =>
            assertStripeReferenceEnvironmentConsistency({
              activeEnvironment: active,
              storedEnvironment: stored,
            })
          ).toThrow();
        } else {
          expect(() =>
            assertStripeReferenceEnvironmentConsistency({
              activeEnvironment: active,
              storedEnvironment: stored,
            })
          ).not.toThrow();
        }
      }
    }
  });
});

describe("assertStripeReferenceEnvironmentConsistencyOrLog — variante journalisée (BLOC I)", () => {
  it("cas cohérent (test/test) : ne lève rien, retourne normalement", () => {
    expect(() =>
      assertStripeReferenceEnvironmentConsistencyOrLog({
        activeEnvironment: "test",
        storedEnvironment: "test",
        operation: "capture_payment",
        operationStartedAt: Date.now(),
        correlationId: "corr_1",
        identifiers: { paymentId: "pay_1" },
        refType: "payments/pay_1",
      })
    ).not.toThrow();
  });

  it("cas mismatch (test stocké, live actif) : lève la MÊME erreur que la variante pure", () => {
    let thrown: Error | null = null;
    try {
      assertStripeReferenceEnvironmentConsistencyOrLog({
        activeEnvironment: "live",
        storedEnvironment: "test",
        operation: "capture_payment",
        operationStartedAt: Date.now(),
        correlationId: "corr_2",
        identifiers: { paymentId: "pay_2" },
        refType: "payments/pay_2",
      });
    } catch (err) {
      thrown = err as Error;
    }
    expect(thrown).not.toBeNull();
    expect(thrown!.message).toBe(stripeEnvironmentMismatchError().message);
  });

  it("journalise avant de re-lever : logFinancialFailure() (BLOC I) est bien appelé avec le code d'erreur STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE lors d'un mismatch", () => {
    const logSpy = jest.spyOn(observability, "logFinancialFailure");
    try {
      expect(() =>
        assertStripeReferenceEnvironmentConsistencyOrLog({
          activeEnvironment: "live",
          storedEnvironment: "test",
          operation: "refund_payment",
          operationStartedAt: Date.now(),
          correlationId: "corr_3",
          identifiers: { paymentId: "pay_3", refundId: "ref_3" },
          refType: "payments/pay_3",
        })
      ).toThrow();
      expect(logSpy).toHaveBeenCalledTimes(1);
      expect(logSpy).toHaveBeenCalledWith(
        "refund_payment",
        expect.any(Number),
        STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE,
        { paymentId: "pay_3", refundId: "ref_3" },
        expect.objectContaining({ correlationId: "corr_3" })
      );
    } finally {
      logSpy.mockRestore();
    }
  });

  it("cas cohérent (test/test) : logFinancialFailure() n'est JAMAIS appelé (aucun log d'anomalie sans anomalie réelle)", () => {
    const logSpy = jest.spyOn(observability, "logFinancialFailure");
    try {
      assertStripeReferenceEnvironmentConsistencyOrLog({
        activeEnvironment: "test",
        storedEnvironment: "test",
        operation: "capture_payment",
        operationStartedAt: Date.now(),
        correlationId: "corr_4",
        identifiers: { paymentId: "pay_4" },
        refType: "payments/pay_4",
      });
      expect(logSpy).not.toHaveBeenCalled();
    } finally {
      logSpy.mockRestore();
    }
  });
});

describe("STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE — code d'erreur interne stable", () => {
  it("vaut exactement 'stripe_environment_mismatch' (jamais renommé sans migration explicite)", () => {
    expect(STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE).toBe("stripe_environment_mismatch");
  });
});

describe("stripeEnvironmentMismatchError — message client générique", () => {
  it("ne contient jamais 'test'/'live' ni un identifiant de référence Stripe", () => {
    const err = stripeEnvironmentMismatchError();
    expect(err.message).not.toMatch(/test|live|sk_|rk_|pi_|re_|po_/i);
    expect(err.message.length).toBeGreaterThan(0);
  });
});
