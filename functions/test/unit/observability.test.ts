// ---------------------------------------------------------------------------
// Tests unitaires — observability.ts (Phase 6, Bloc I).
//
// Teste la STRUCTURE produite par l'utilitaire (jamais le texte exact d'un
// console.log — voir directive Bloc I, point "tests unitaires
// observabilité"). Aucun émulateur requis : imports directs depuis
// `../../src/lib/observability`, pur Jest.
// ---------------------------------------------------------------------------

import {
  buildFinancialLogEntry,
  computeDurationMs,
  logFinancialFailure,
  logFinancialOperation,
  logFinancialSuccess,
  resolveCorrelationId,
  sanitizeMetadata,
  startFinancialOperationTimer,
} from "../../src/lib/observability";

describe("observability — schéma success", () => {
  it("produit une entrée avec correlation_id, operation, result=success, duration_ms et sans error_code", () => {
    const entry = buildFinancialLogEntry({
      operation: "capturePayment",
      result: "success",
      durationMs: 123,
      paymentId: "pay_123",
      missionId: "mission_1",
    });

    expect(entry.operation).toBe("capturePayment");
    expect(entry.result).toBe("success");
    expect(entry.duration_ms).toBe(123);
    expect(typeof entry.correlation_id).toBe("string");
    expect(entry.correlation_id.length).toBeGreaterThan(0);
    expect(entry.payment_id).toBe("pay_123");
    expect(entry.mission_id).toBe("mission_1");
    expect(entry.error_code).toBeUndefined();
  });
});

describe("observability — schéma failure", () => {
  it("produit une entrée avec result=failure ET error_code obligatoire", () => {
    const entry = buildFinancialLogEntry({
      operation: "capturePayment",
      result: "failure",
      durationMs: 42,
      errorCode: "provider_error",
      paymentId: "pay_456",
    });

    expect(entry.result).toBe("failure");
    expect(entry.error_code).toBe("provider_error");
    expect(entry.duration_ms).toBe(42);
  });

  it("rejette une entrée failure SANS error_code (pas de message libre comme seule source)", () => {
    expect(() =>
      buildFinancialLogEntry({
        operation: "capturePayment",
        result: "failure",
        durationMs: 10,
      })
    ).toThrow();
  });

  it("rejette une entrée failure avec error_code vide", () => {
    expect(() =>
      buildFinancialLogEntry({
        operation: "capturePayment",
        result: "failure",
        durationMs: 10,
        errorCode: "   ",
      })
    ).toThrow();
  });
});

describe("observability — correlation ID", () => {
  it("génère un correlation_id côté serveur si aucun n'est fourni", () => {
    const id1 = resolveCorrelationId(undefined);
    const id2 = resolveCorrelationId(null);
    expect(typeof id1).toBe("string");
    expect(id1.length).toBeGreaterThan(0);
    expect(typeof id2).toBe("string");
    expect(id2.length).toBeGreaterThan(0);
    // Deux générations successives ne doivent jamais collisionner.
    expect(id1).not.toBe(id2);
  });

  it("propage un correlation_id EXISTANT tel quel, sans le régénérer", () => {
    const existing = "corr_abc_existing_123";
    expect(resolveCorrelationId(existing)).toBe(existing);
  });

  it("propage le correlation_id existant à travers buildFinancialLogEntry", () => {
    const existing = "evt_stripe_webhook_789";
    const entry = buildFinancialLogEntry({
      operation: "processStripeWebhook",
      result: "success",
      durationMs: 5,
      correlationId: existing,
    });
    expect(entry.correlation_id).toBe(existing);
  });

  it("ignore une chaîne vide/blanche comme correlation_id existant et en génère un nouveau", () => {
    const entry = buildFinancialLogEntry({
      operation: "capturePayment",
      result: "success",
      durationMs: 5,
      correlationId: "   ",
    });
    expect(entry.correlation_id.trim().length).toBeGreaterThan(0);
    expect(entry.correlation_id).not.toBe("   ");
  });
});

describe("observability — sanitization : exclusion des secrets", () => {
  it("exclut une clé Stripe secrète (secretKey) de metadata", () => {
    const sanitized = sanitizeMetadata({
      secretKey: "sk_live_abcdef1234567890",
      paymentId: "pay_1",
    }) as Record<string, unknown>;
    expect(sanitized.secretKey).toBe("[REDACTED]");
    expect(sanitized.paymentId).toBe("pay_1");
  });

  it("exclut une valeur ressemblant à une clé Stripe secrète MÊME sous une clé au nom innocent", () => {
    const sanitized = sanitizeMetadata({
      value: "sk_test_1234567890abcdef",
    }) as Record<string, unknown>;
    expect(sanitized.value).toBe("[REDACTED]");
  });

  it("exclut le webhook signing secret (webhookSecret / whsec_ value)", () => {
    const sanitized = sanitizeMetadata({
      webhookSecret: "some-secret-value",
      stripeWebhookSigningSecret: "whsec_abcdefghijklmnop",
      raw: "whsec_zzzzzzzzzzzzzzzz",
    }) as Record<string, unknown>;
    expect(sanitized.webhookSecret).toBe("[REDACTED]");
    expect(sanitized.stripeWebhookSigningSecret).toBe("[REDACTED]");
    expect(sanitized.raw).toBe("[REDACTED]");
  });

  it("exclut l'en-tête Authorization (nom de clé ET valeur Bearer complète)", () => {
    const sanitized = sanitizeMetadata({
      Authorization: "Bearer abc.def.ghi",
      authorization: "Bearer xyz",
      headers: { authorization: "Bearer nested-token" },
    }) as Record<string, unknown>;
    expect(sanitized.Authorization).toBe("[REDACTED]");
    expect(sanitized.authorization).toBe("[REDACTED]");
    expect((sanitized.headers as Record<string, unknown>).authorization).toBe("[REDACTED]");
  });

  it("exclut les tokens (token, accessToken, refreshToken)", () => {
    const sanitized = sanitizeMetadata({
      token: "abcdef",
      accessToken: "ghijkl",
      refreshToken: "mnopqr",
      idToken: "should also be caught by /token/ pattern? verify",
    }) as Record<string, unknown>;
    expect(sanitized.token).toBe("[REDACTED]");
    expect(sanitized.accessToken).toBe("[REDACTED]");
    expect(sanitized.refreshToken).toBe("[REDACTED]");
  });

  it("exclut les données de carte sensibles (cardNumber, cvc, cvv)", () => {
    const sanitized = sanitizeMetadata({
      cardNumber: "4242424242424242",
      cvc: "123",
      cvv: "456",
      bankAccountNumber: "0001234567",
      iban: "FR7630006000011234567890189",
    }) as Record<string, unknown>;
    expect(sanitized.cardNumber).toBe("[REDACTED]");
    expect(sanitized.cvc).toBe("[REDACTED]");
    expect(sanitized.cvv).toBe("[REDACTED]");
    expect(sanitized.bankAccountNumber).toBe("[REDACTED]");
    expect(sanitized.iban).toBe("[REDACTED]");
  });

  it("exclut un objet provider complet nommé de façon suspecte (rawPayload / providerObject)", () => {
    const sanitized = sanitizeMetadata({
      rawPayload: { anything: "here", nested: { secret: "sk_live_should_not_matter" } },
      providerObject: { id: "evt_1", data: {} },
    }) as Record<string, unknown>;
    expect(sanitized.rawPayload).toBe("[REDACTED]");
    expect(sanitized.providerObject).toBe("[REDACTED]");
  });

  it("exclut credentials et secrets Firebase génériques", () => {
    const sanitized = sanitizeMetadata({
      credentials: { user: "x", pass: "y" },
      firebaseSecret: "abc",
      firebaseAdminKey: "def",
    }) as Record<string, unknown>;
    expect(sanitized.credentials).toBe("[REDACTED]");
    expect(sanitized.firebaseSecret).toBe("[REDACTED]");
    expect(sanitized.firebaseAdminKey).toBe("[REDACTED]");
  });

  it("sanitize récursivement des structures imbriquées profondes sans planter", () => {
    const deep = { a: { b: { c: { d: { secretKey: "sk_live_deep" } } } } };
    const sanitized = sanitizeMetadata(deep) as any;
    expect(sanitized.a.b.c.d.secretKey).toBe("[REDACTED]");
  });

  it("préserve les identifiants métier autorisés (mission_id, payment_id, refund_id, payout_id, dispute_id, provider_event_id, amountMinor, status)", () => {
    const sanitized = sanitizeMetadata({
      missionId: "mission_42",
      paymentId: "pay_42",
      refundId: "refund_42",
      payoutId: "payout_42",
      disputeId: "dispute_42",
      providerEventId: "evt_42",
      amountMinor: 12345,
      status: "captured",
      currency: "CAD",
    }) as Record<string, unknown>;
    expect(sanitized.missionId).toBe("mission_42");
    expect(sanitized.paymentId).toBe("pay_42");
    expect(sanitized.refundId).toBe("refund_42");
    expect(sanitized.payoutId).toBe("payout_42");
    expect(sanitized.disputeId).toBe("dispute_42");
    expect(sanitized.providerEventId).toBe("evt_42");
    expect(sanitized.amountMinor).toBe(12345);
    expect(sanitized.status).toBe("captured");
    expect(sanitized.currency).toBe("CAD");
  });

  it("sanitize les metadata passées à buildFinancialLogEntry (bout-en-bout)", () => {
    const entry = buildFinancialLogEntry({
      operation: "createAndAuthorizeMissionPayment",
      result: "success",
      durationMs: 10,
      paymentId: "pay_1",
      metadata: {
        providerPaymentIntentId: "pi_123",
        secretKey: "sk_live_leak_attempt",
        amountMinor: 5000,
      },
    });
    expect(entry.metadata?.providerPaymentIntentId).toBe("pi_123");
    expect(entry.metadata?.amountMinor).toBe(5000);
    expect(entry.metadata?.secretKey).toBe("[REDACTED]");
  });
});

describe("observability — duration_ms", () => {
  it("duration_ms est un nombre valide (>= 0)", () => {
    const entry = buildFinancialLogEntry({
      operation: "submitDriverPayout",
      result: "success",
      durationMs: 250,
    });
    expect(typeof entry.duration_ms).toBe("number");
    expect(Number.isFinite(entry.duration_ms)).toBe(true);
    expect(entry.duration_ms).toBeGreaterThanOrEqual(0);
  });

  it("rejette une durée négative (jamais inventée, doit provenir d'une mesure réelle)", () => {
    expect(() =>
      buildFinancialLogEntry({
        operation: "submitDriverPayout",
        result: "success",
        durationMs: -5,
      })
    ).toThrow();
  });

  it("rejette une durée non numérique", () => {
    expect(() =>
      buildFinancialLogEntry({
        operation: "submitDriverPayout",
        result: "success",
        // @ts-expect-error - test volontaire d'une valeur invalide
        durationMs: "not-a-number",
      })
    ).toThrow();
  });

  it("computeDurationMs calcule une durée réelle positive à partir d'un timestamp de départ", () => {
    const startedAt = startFinancialOperationTimer();
    const durationMs = computeDurationMs(startedAt);
    expect(typeof durationMs).toBe("number");
    expect(durationMs).toBeGreaterThanOrEqual(0);
  });
});

describe("observability — error_code sur failure", () => {
  it("le champ error_code est présent et non-vide quand result=failure", () => {
    const entry = buildFinancialLogEntry({
      operation: "refundPayment",
      result: "failure",
      durationMs: 30,
      errorCode: "card_declined",
      refundId: "refund_9",
    });
    expect(entry.error_code).toBe("card_declined");
    expect(entry.refund_id).toBe("refund_9");
  });

  it("error_code est absent quand result=success", () => {
    const entry = buildFinancialLogEntry({
      operation: "refundPayment",
      result: "success",
      durationMs: 30,
    });
    expect(entry.error_code).toBeUndefined();
  });
});

describe("observability — API sucre syntaxique (logFinancialSuccess / logFinancialFailure / logFinancialOperation)", () => {
  it("logFinancialSuccess produit une structure success avec durée réellement mesurée", () => {
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialSuccess(
      "capturePayment",
      startedAt,
      { paymentId: "pay_77", missionId: "mission_77" },
      { metadata: { amountMinor: 1000 } }
    );
    expect(entry.operation).toBe("capturePayment");
    expect(entry.result).toBe("success");
    expect(entry.payment_id).toBe("pay_77");
    expect(entry.mission_id).toBe("mission_77");
    expect(entry.duration_ms).toBeGreaterThanOrEqual(0);
    expect(entry.metadata?.amountMinor).toBe(1000);
  });

  it("logFinancialFailure exige un errorCode et produit une structure failure", () => {
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialFailure("capturePayment", startedAt, "capture_failed", {
      paymentId: "pay_88",
    });
    expect(entry.result).toBe("failure");
    expect(entry.error_code).toBe("capture_failed");
    expect(entry.payment_id).toBe("pay_88");
  });

  it("logFinancialOperation retourne l'entrée construite (permet la propagation du correlation_id résolu)", () => {
    const entry = logFinancialOperation({
      operation: "submitDriverPayout",
      result: "success",
      durationMs: 5,
      payoutId: "payout_1",
    });
    expect(entry.correlation_id).toBeDefined();
    expect(entry.payout_id).toBe("payout_1");
  });

  it("ne journalise jamais de secret même via l'API sucre syntaxique", () => {
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialFailure(
      "processStripeWebhook",
      startedAt,
      "webhook_dispatch_failed",
      { providerEventId: "evt_1" },
      { metadata: { stripeSecretKey: "sk_live_should_never_appear" } }
    );
    expect(entry.metadata?.stripeSecretKey).toBe("[REDACTED]");
  });
});

describe("observability — webhook : correlation ID et provider_event_id", () => {
  it("propage event.id à la fois comme correlation_id ET comme provider_event_id (pattern processStripeWebhook.ts)", () => {
    const stripeEventId = "evt_1NxYzAbCdEfGhIjK";
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialSuccess(
      "stripe_webhook_processing",
      startedAt,
      { providerEventId: stripeEventId, missionId: "mission_1", paymentId: "pay_1" },
      { correlationId: stripeEventId, metadata: { eventType: "payment_intent.succeeded" } }
    );
    expect(entry.correlation_id).toBe(stripeEventId);
    expect(entry.provider_event_id).toBe(stripeEventId);
  });

  it("conserve provider_event_id même en cas de failure webhook (retry Stripe traçable)", () => {
    const stripeEventId = "evt_failed_case_1";
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialFailure(
      "stripe_webhook_processing",
      startedAt,
      "webhook_dispatch_failed",
      { providerEventId: stripeEventId },
      { correlationId: stripeEventId, message: "dispatch error" }
    );
    expect(entry.result).toBe("failure");
    expect(entry.provider_event_id).toBe(stripeEventId);
    expect(entry.correlation_id).toBe(stripeEventId);
    expect(entry.error_code).toBe("webhook_dispatch_failed");
  });

  it("branche métier interne (ex: payment_captured) partage le même correlation_id que le log de synthèse webhook", () => {
    const stripeEventId = "evt_shared_corr_1";
    const startedAt = startFinancialOperationTimer();
    const branchEntry = logFinancialSuccess(
      "payment_captured",
      startedAt,
      { paymentId: "pay_1", providerEventId: stripeEventId },
      { correlationId: stripeEventId }
    );
    const summaryEntry = logFinancialSuccess(
      "stripe_webhook_processing",
      startedAt,
      { providerEventId: stripeEventId },
      { correlationId: stripeEventId }
    );
    expect(branchEntry.correlation_id).toBe(summaryEntry.correlation_id);
  });
});

describe("observability — réconciliation : usage du correlation ID", () => {
  it("logFinancialSuccess pour reconciliation_run accepte et conserve un correlation_id propagé depuis l'appelant", () => {
    const propagatedCorrelationId = "reconciliation_run_from_caller_123";
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialSuccess(
      "reconciliation_run",
      startedAt,
      {},
      { correlationId: propagatedCorrelationId, metadata: { reportId: "report_1", anomalyCount: 0 } }
    );
    expect(entry.correlation_id).toBe(propagatedCorrelationId);
    expect(entry.result).toBe("success");
  });

  it("reconciliation_anomaly_detected est une structure failure avec error_code dédié, sans dupliquer les anomalies brutes", () => {
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialFailure(
      "reconciliation_anomaly_detected",
      startedAt,
      "anomalies_detected",
      {},
      {
        correlationId: "reconciliation_run_2",
        metadata: { reportId: "report_2", anomalyCount: 3, anomalyTypes: ["payment_amount_mismatch"] },
      }
    );
    expect(entry.result).toBe("failure");
    expect(entry.error_code).toBe("anomalies_detected");
    expect(entry.metadata?.anomalyCount).toBe(3);
    // Le résumé ne doit contenir que des types/compteurs, jamais le détail complet.
    expect(entry.metadata).not.toHaveProperty("anomalies");
  });

  it("reconciliation_run failure (chemin d'échec réel) produit result=failure + error_code cohérents", () => {
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialFailure(
      "reconciliation_run",
      startedAt,
      "reconciliation_failed",
      {},
      { correlationId: "reconciliation_error_case", message: "PaymentProvider unavailable" }
    );
    expect(entry.result).toBe("failure");
    expect(entry.error_code).toBe("reconciliation_failed");
    expect(typeof entry.duration_ms).toBe("number");
  });
});

describe("observability — cohérence structurelle success/failure (rappel transverse)", () => {
  it("une entrée success n'a jamais error_code, une entrée failure l'a toujours", () => {
    const startedAt = startFinancialOperationTimer();
    const success = logFinancialSuccess("financial_adjustment_created", startedAt, { missionId: "m1" });
    const failure = logFinancialFailure(
      "financial_adjustment_created",
      startedAt,
      "ledger_entry_creation_failed",
      { missionId: "m1" }
    );
    expect(success.error_code).toBeUndefined();
    expect(failure.error_code).toBe("ledger_entry_creation_failed");
    expect(success.result).toBe("success");
    expect(failure.result).toBe("failure");
  });

  it("les metadata sensibles restent supprimées même dans un scénario d'intégration réaliste (webhook + secret Stripe accidentel)", () => {
    const startedAt = startFinancialOperationTimer();
    const entry = logFinancialSuccess(
      "payout_paid",
      startedAt,
      { payoutId: "payout_9", providerEventId: "evt_9" },
      {
        correlationId: "evt_9",
        metadata: {
          status: "paid",
          // Fuite accidentelle simulée d'un objet provider complet.
          rawPayload: { id: "po_9", destination: "ba_123", api_key: "sk_live_leak" },
        },
      }
    );
    expect(entry.metadata?.status).toBe("paid");
    expect(entry.metadata?.rawPayload).toBe("[REDACTED]");
  });
});
