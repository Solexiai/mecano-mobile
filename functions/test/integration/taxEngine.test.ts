// ---------------------------------------------------------------------------
// Test d'intégration — Bloc E (Taxes) : updateTaxConfiguration + moteur de
// taxes configurable câblé dans acceptDelivery (Phase 6, directive 38
// points, points 14/15/16).
//
// Couvre exactement les scénarios demandés :
//   - configuration active appliquée correctement
//   - configuration inactive (enabled=false) ignorée
//   - configuration future (effective_from > maintenant) ignorée
//   - configuration expirée (effective_until <= maintenant) ignorée
//   - version correcte résolue (jamais un overwrite, alias `_current` à jour)
//   - changement de taux : nouvelle version créée, ancienne conservée
//   - snapshot fiscal ANCIEN inchangé après une modification de config
//     ultérieure (immutabilité rétroactive)
//   - zéro taxe si aucune configuration applicable (comportement de repli
//     explicite du taux plat legacy, PAS une pseudo-règle silencieuse)
//   - cents entiers stricts sur tous les montants de taxe
//   - plusieurs composantes taxables cumulées (ex: GST + QST)
//   - permissions admin (admin/super_admin autorisés)
//   - refus customer/driver en écriture (permission-denied)
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import {
  updateTaxConfiguration,
  UpdateTaxConfigurationRequest,
} from "../../src/functions/updateTaxConfiguration";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import { admin, db } from "../../src/lib/admin";
import { readActiveTaxConfigs, calculateTaxes } from "../../src/lib/taxEngine";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

const ADMIN_ID = "tax_admin_001";
const SUPER_ADMIN_ID = "tax_super_admin_001";
const NON_ADMIN_ID = "tax_customer_stranger_001";
const JURISDICTION = "QC_TEST"; // juridiction isolée pour ne jamais interférer avec d'autres tests
const TAX_CODE_GST = "GST_TEST";
const TAX_CODE_QST = "QST_TEST";

function buildRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { role } as unknown as DecodedIdToken, rawToken: "fake-raw-token" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function cleanupTaxConfigs(jurisdiction: string, taxCodes: string[]): Promise<void> {
  const snap = await db.collection("tax_configs").where("jurisdiction", "==", jurisdiction).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
  // Sécurité supplémentaire : suppression explicite des IDs connus au cas où
  // une requête indexée composite ne serait pas encore prête côté émulateur.
  const ids: string[] = [];
  for (const code of taxCodes) {
    ids.push(`${jurisdiction}_${code}_current`);
    for (let v = 1; v <= 10; v++) ids.push(`${jurisdiction}_${code}_v${v}`);
  }
  await Promise.all(ids.map((id) => db.collection("tax_configs").doc(id).delete()));
}

async function cleanupAuditLogs(targetIdPrefix: string): Promise<void> {
  const snap = await db
    .collection("audit_logs")
    .where("action", "==", "tax_configuration_changed")
    .get();
  await Promise.all(
    snap.docs
      .filter((d) => (d.data().target_id as string).startsWith(targetIdPrefix))
      .map((d) => d.ref.delete())
  );
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("updateTaxConfiguration", () => {
  afterEach(async () => {
    await cleanupTaxConfigs(JURISDICTION, [TAX_CODE_GST, TAX_CODE_QST]);
    await cleanupAuditLogs(JURISDICTION);
  });

  it("crée la version 1 (admin) et met à jour l'alias _current + journalise l'audit_log", async () => {
    const now = Date.now();
    const result = await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS test (5%)",
        rate: 0.05,
        taxableComponents: ["transport", "platform_fees"],
        effectiveFromMillis: now - 1000,
        effectiveUntilMillis: null,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );

    expect(result.success).toBe(true);
    expect(result.version).toBe(1);
    expect(result.configId).toBe(`${JURISDICTION}_${TAX_CODE_GST}_v1`);

    const versionSnap = await db.collection("tax_configs").doc(result.configId).get();
    expect(versionSnap.exists).toBe(true);
    const versionDoc = versionSnap.data()!;
    expect(versionDoc.rate).toBe(0.05);
    expect(versionDoc.version).toBe(1);
    expect(versionDoc.enabled).toBe(true);
    expect(versionDoc.updated_by_user_id).toBe(ADMIN_ID);

    const aliasSnap = await db
      .collection("tax_configs")
      .doc(`${JURISDICTION}_${TAX_CODE_GST}_current`)
      .get();
    expect(aliasSnap.exists).toBe(true);
    expect(aliasSnap.data()!.latest_version).toBe(1);
    expect(aliasSnap.data()!.latest_config_id).toBe(result.configId);

    const auditSnap = await db
      .collection("audit_logs")
      .where("action", "==", "tax_configuration_changed")
      .where("target_id", "==", result.configId)
      .get();
    expect(auditSnap.size).toBe(1);
    expect(auditSnap.docs[0].data().actor_user_id).toBe(ADMIN_ID);
  });

  it("super_admin autorisé également", async () => {
    const result = await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(SUPER_ADMIN_ID, "super_admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS test (5%)",
        rate: 0.05,
        taxableComponents: ["transport"],
        effectiveFromMillis: Date.now() - 1000,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );
    expect(result.success).toBe(true);
    expect(result.version).toBe(1);
  });

  it("refuse (via requireAdminOrAbove) un appelant customer/driver — permission-denied", async () => {
    await expect(
      updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(NON_ADMIN_ID, "customer", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "TPS test (5%)",
          rate: 0.05,
          taxableComponents: ["transport"],
          effectiveFromMillis: Date.now(),
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      )
    ).rejects.toThrow();

    await expect(
      updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(NON_ADMIN_ID, "driver", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "TPS test (5%)",
          rate: 0.05,
          taxableComponents: ["transport"],
          effectiveFromMillis: Date.now(),
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      )
    ).rejects.toThrow();
  });

  it("refuse un rate hors [0,1] (invalid-argument)", async () => {
    await expect(
      updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "Invalide",
          rate: 1.5,
          taxableComponents: ["transport"],
          effectiveFromMillis: Date.now(),
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      )
    ).rejects.toThrow();
  });

  it(
    "CHANGEMENT DE TAUX : un second appel crée la version 2 sans écraser la version 1 " +
      "— l'alias pointe vers la version 2, l'historique v1 reste lisible et inchangé",
    async () => {
      const v1 = await updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "TPS test (5%)",
          rate: 0.05,
          taxableComponents: ["transport", "platform_fees"],
          effectiveFromMillis: Date.now() - 10_000,
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );
      expect(v1.version).toBe(1);

      const v2 = await updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "TPS test (6%, révisée)",
          rate: 0.06,
          taxableComponents: ["transport", "platform_fees"],
          effectiveFromMillis: Date.now(),
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );
      expect(v2.version).toBe(2);
      expect(v2.configId).toBe(`${JURISDICTION}_${TAX_CODE_GST}_v2`);

      // ---- La version 1 existe TOUJOURS, INCHANGÉE ----
      const v1Snap = await db.collection("tax_configs").doc(v1.configId).get();
      expect(v1Snap.exists).toBe(true);
      expect(v1Snap.data()!.rate).toBe(0.05);
      expect(v1Snap.data()!.version).toBe(1);

      // ---- L'alias pointe désormais vers la version 2 ----
      const aliasSnap = await db
        .collection("tax_configs")
        .doc(`${JURISDICTION}_${TAX_CODE_GST}_current`)
        .get();
      expect(aliasSnap.data()!.latest_version).toBe(2);
      expect(aliasSnap.data()!.latest_config_id).toBe(v2.configId);
    }
  );
});

describe("readActiveTaxConfigs / calculateTaxes — résolution temporelle", () => {
  afterEach(async () => {
    await cleanupTaxConfigs(JURISDICTION, [TAX_CODE_GST, TAX_CODE_QST]);
    await cleanupAuditLogs(JURISDICTION);
  });

  it("CONFIG ACTIVE : appliquée correctement (rate exact, cents entiers)", async () => {
    await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS active",
        rate: 0.05,
        taxableComponents: ["transport"],
        effectiveFromMillis: Date.now() - 10_000,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );

    const configs = await readActiveTaxConfigs(JURISDICTION, Date.now());
    expect(configs).toHaveLength(1);

    const result = calculateTaxes({
      taxableAmountMinor: 10000, // 100.00 $
      configs,
      jurisdiction: JURISDICTION,
      applyToTransport: true,
      applyToPlatformFees: false,
    });
    expect(result.totalTaxMinor).toBe(500); // 5.00 $ exact
    expect(Number.isInteger(result.totalTaxMinor)).toBe(true);
    expect(result.lines).toHaveLength(1);
    expect(result.lines[0].amountMinor).toBe(500);
  });

  it("CONFIG INACTIVE (enabled=false) : ignorée, aucune taxe appliquée", async () => {
    await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS désactivée",
        rate: 0.05,
        taxableComponents: ["transport"],
        effectiveFromMillis: Date.now() - 10_000,
        enabled: false,
        taxRegistrationOwner: "platform",
      })
    );

    const configs = await readActiveTaxConfigs(JURISDICTION, Date.now());
    expect(configs).toHaveLength(0);
  });

  it("CONFIG FUTURE (effective_from > maintenant) : ignorée", async () => {
    await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS future",
        rate: 0.05,
        taxableComponents: ["transport"],
        effectiveFromMillis: Date.now() + 999_999_000, // très loin dans le futur
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );

    const configs = await readActiveTaxConfigs(JURISDICTION, Date.now());
    expect(configs).toHaveLength(0);
  });

  it("CONFIG EXPIRÉE (effective_until <= maintenant) : ignorée", async () => {
    const now = Date.now();
    await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS expirée",
        rate: 0.05,
        taxableComponents: ["transport"],
        effectiveFromMillis: now - 20_000,
        effectiveUntilMillis: now - 10_000,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );

    const configs = await readActiveTaxConfigs(JURISDICTION, now);
    expect(configs).toHaveLength(0);
  });

  it(
    "VERSION CORRECTE : après un changement de taux, readActiveTaxConfigs() " +
      "résout TOUJOURS la DERNIÈRE version active (jamais une version périmée)",
    async () => {
      await updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "TPS v1",
          rate: 0.05,
          taxableComponents: ["transport"],
          effectiveFromMillis: Date.now() - 20_000,
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );
      await updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE_GST,
          taxType: "gst",
          displayName: "TPS v2",
          rate: 0.07,
          taxableComponents: ["transport"],
          effectiveFromMillis: Date.now() - 5_000,
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );

      const configs = await readActiveTaxConfigs(JURISDICTION, Date.now());
      expect(configs).toHaveLength(1);
      expect(configs[0].version).toBe(2);
      expect(configs[0].rate).toBe(0.07);
    }
  );

  it("ZÉRO TAXE si aucune configuration applicable pour la juridiction (comportement de repli explicite)", async () => {
    const configs = await readActiveTaxConfigs("JURIDICTION_INEXISTANTE_XYZ", Date.now());
    expect(configs).toHaveLength(0);
    const result = calculateTaxes({
      taxableAmountMinor: 10000,
      configs,
      jurisdiction: "JURIDICTION_INEXISTANTE_XYZ",
      applyToTransport: true,
      applyToPlatformFees: true,
    });
    expect(result.totalTaxMinor).toBe(0);
    expect(result.lines).toHaveLength(0);
  });

  it("PLUSIEURS COMPOSANTES TAXABLES CUMULÉES (GST + QST) : total = somme des lignes, cents entiers", async () => {
    await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_GST,
        taxType: "gst",
        displayName: "TPS 5%",
        rate: 0.05,
        taxableComponents: ["transport", "platform_fees"],
        effectiveFromMillis: Date.now() - 10_000,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );
    await updateTaxConfiguration.run(
      buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
        jurisdiction: JURISDICTION,
        taxCode: TAX_CODE_QST,
        taxType: "qst",
        displayName: "TVQ 9.975%",
        rate: 0.09975,
        taxableComponents: ["transport", "platform_fees"],
        effectiveFromMillis: Date.now() - 10_000,
        enabled: true,
        taxRegistrationOwner: "platform",
      })
    );

    const configs = await readActiveTaxConfigs(JURISDICTION, Date.now());
    expect(configs).toHaveLength(2);

    const result = calculateTaxes({
      taxableAmountMinor: 10000, // 100.00 $
      configs,
      jurisdiction: JURISDICTION,
      applyToTransport: true,
      applyToPlatformFees: true,
    });
    expect(result.lines).toHaveLength(2);
    // GST: round(10000 * 0.05) = 500 ; QST: round(10000 * 0.09975) = 998 (arrondi)
    const gstLine = result.lines.find((l) => l.taxType === "gst")!;
    const qstLine = result.lines.find((l) => l.taxType === "qst")!;
    expect(gstLine.amountMinor).toBe(500);
    expect(qstLine.amountMinor).toBe(998);
    expect(result.totalTaxMinor).toBe(gstLine.amountMinor + qstLine.amountMinor);
    expect(Number.isInteger(result.totalTaxMinor)).toBe(true);
  });
});

describe("acceptDelivery — snapshot fiscal figé (Phase 6, point 15)", () => {
  const CUSTOMER_ID = "tax_e2e_customer_001";
  const DRIVER_ID = "tax_e2e_driver_001";
  const MISSION_ID = "tax_e2e_mission_001";
  const MISSION_ID_2 = "tax_e2e_mission_002";
  const PRICING_VERSION = "TAX-TEST-PRICING-001";

  function buildDriverRequest(missionId: string): CallableRequest<AcceptDeliveryRequest> {
    return {
      data: { missionId },
      auth: { uid: DRIVER_ID, token: {} as DecodedIdToken, rawToken: "fake-raw-token" },
      rawRequest: {} as Request,
      acceptsStreaming: false,
    };
  }

  async function seedDriver(): Promise<void> {
    await db.collection("driver_profiles").doc(DRIVER_ID).set({
      uid: DRIVER_ID,
      full_name: "Chauffeur Fiscal Test",
      city: "Montréal",
      status: "approved",
      service_radius_km: 25,
      accepted_vehicle_categories: ["cargoVan"],
      accepted_item_category_keys: ["furniture"],
      rating: 4.8,
      completed_missions: 42,
      created_at: admin.firestore.Timestamp.now(),
      approved_at: admin.firestore.Timestamp.now(),
      identity_verified: true,
      vehicle_verified: true,
      online_status: "online",
      documents_all_valid: true,
    });
  }

  async function seedMission(missionId: string): Promise<void> {
    await db.collection("delivery_requests").doc(missionId).set({
      customer_id: CUSTOMER_ID,
      customer_display_name: "Client Fiscal Test",
      driver_id: null,
      driver_display_name: null,
      status: "searching_driver",
      item_category_key: "furniture",
      description: "Test fiscal",
      required_vehicle_category: "cargoVan",
      pickup_address: { line1: "1 rue Test", city: "Montréal" },
      dropoff_address: { line1: "2 rue Cible", city: "Laval" },
      distance_km: 10,
      estimated_duration_minutes: 20,
      pricing_version: PRICING_VERSION,
      driver_offer_amount: 0,
      customer_total: 0,
      customer_discount_amount: 0,
      payment_status: "pending",
      active_quote_id: null,
      active_financial_snapshot_id: null,
      created_at: admin.firestore.Timestamp.now(),
      dispatch_zone_geohash: "f25dvk",
    });
  }

  async function seedPricingVersion(): Promise<void> {
    await db
      .collection("pricing_versions")
      .doc(PRICING_VERSION)
      .set(buildPricingConfig({ pricing_version: PRICING_VERSION, tax_rate: 0.14975 }));
  }

  async function seedPaymentProfile(): Promise<void> {
    await db
      .collection("payment_profiles")
      .doc(CUSTOMER_ID)
      .set(buildFakePaymentProfile(CUSTOMER_ID));
  }

  async function cleanupMission(missionId: string): Promise<void> {
    await db.collection("delivery_requests").doc(missionId).delete();
    const [snapshots, events, payments] = await Promise.all([
      db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
      db.collection("delivery_requests").doc(missionId).collection("tracking_events").get(),
      db.collection("payments").where("mission_id", "==", missionId).get(),
    ]);
    await Promise.all([
      ...snapshots.docs.map((d) => d.ref.delete()),
      ...events.docs.map((d) => d.ref.delete()),
      ...payments.docs.map((d) => d.ref.delete()),
    ]);
  }

  beforeAll(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  beforeEach(async () => {
    await Promise.all([seedDriver(), seedPricingVersion(), seedPaymentProfile()]);
  });

  afterEach(async () => {
    await Promise.all([cleanupMission(MISSION_ID), cleanupMission(MISSION_ID_2)]);
    await db.collection("driver_profiles").doc(DRIVER_ID).delete();
    await db.collection("pricing_versions").doc(PRICING_VERSION).delete();
    await db.collection("payment_profiles").doc(CUSTOMER_ID).delete();
    await cleanupTaxConfigs("QC", []); // par sécurité, si un test touche la juridiction par défaut
  });

  it(
    "SANS config Phase 6 active pour la juridiction : tax_snapshot=null, " +
      "customer_tax provient du taux plat legacy (AUCUNE régression)",
    async () => {
      await seedMission(MISSION_ID);
      const result = await acceptDelivery.run(buildDriverRequest(MISSION_ID));
      expect(result.success).toBe(true);

      const snapshotSnap = await db.collection("financial_snapshots").doc(result.snapshotId).get();
      const snapshot = snapshotSnap.data()!;
      expect(snapshot.tax_snapshot).toBeNull();
      // taux plat 0.14975 appliqué au (subtotal + service fee) — juste vérifier > 0
      expect(snapshot.customer_tax).toBeGreaterThan(0);
    }
  );

  it(
    "AVEC une config Phase 6 active pour 'QC' (juridiction par défaut) : tax_snapshot figé, " +
      "customer_tax dérivé EXACTEMENT du moteur Phase 6 (pas du taux plat)",
    async () => {
      await updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: "QC",
          taxCode: "GST_E2E_TEST",
          taxType: "gst",
          displayName: "TPS E2E test (5%)",
          rate: 0.05,
          taxableComponents: ["transport", "platform_fees"],
          effectiveFromMillis: Date.now() - 10_000,
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );

      try {
        await seedMission(MISSION_ID);
        const result = await acceptDelivery.run(buildDriverRequest(MISSION_ID));
        expect(result.success).toBe(true);

        const snapshotSnap = await db
          .collection("financial_snapshots")
          .doc(result.snapshotId)
          .get();
        const snapshot = snapshotSnap.data()!;
        expect(snapshot.tax_snapshot).not.toBeNull();
        expect(snapshot.tax_snapshot.tax_jurisdiction).toBe("QC");
        expect(snapshot.tax_snapshot.total_tax_minor).toBeGreaterThan(0);
        expect(Number.isInteger(snapshot.tax_snapshot.total_tax_minor)).toBe(true);
        expect(snapshot.tax_snapshot.tax_version_ids).toEqual(["QC_GST_E2E_TEST_v1"]);
        // customer_tax (dollars, legacy) doit correspondre EXACTEMENT à
        // total_tax_minor converti en dollars (frontière money.ts).
        expect(snapshot.customer_tax).toBeCloseTo(snapshot.tax_snapshot.total_tax_minor / 100, 6);
      } finally {
        await cleanupTaxConfigs("QC", ["GST_E2E_TEST"]);
      }
    }
  );

  it(
    "IMMUTABILITÉ RÉTROACTIVE : une modification de tax_configs APRÈS acceptation " +
      "ne modifie JAMAIS le tax_snapshot déjà figé sur la mission historique",
    async () => {
      await updateTaxConfiguration.run(
        buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: "QC",
          taxCode: "GST_E2E_TEST",
          taxType: "gst",
          displayName: "TPS E2E v1 (5%)",
          rate: 0.05,
          taxableComponents: ["transport", "platform_fees"],
          effectiveFromMillis: Date.now() - 10_000,
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );

      try {
        await seedMission(MISSION_ID);
        const result = await acceptDelivery.run(buildDriverRequest(MISSION_ID));

        const beforeSnap = await db
          .collection("financial_snapshots")
          .doc(result.snapshotId)
          .get();
        const frozenTaxSnapshot = beforeSnap.data()!.tax_snapshot;
        const frozenTotalTaxMinor = frozenTaxSnapshot.total_tax_minor;

        // ---- Modification ULTÉRIEURE de la configuration fiscale ----
        await updateTaxConfiguration.run(
          buildRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
            jurisdiction: "QC",
            taxCode: "GST_E2E_TEST",
            taxType: "gst",
            displayName: "TPS E2E v2 (20%, changement majeur)",
            rate: 0.2,
            taxableComponents: ["transport", "platform_fees"],
            effectiveFromMillis: Date.now(),
            enabled: true,
            taxRegistrationOwner: "platform",
          })
        );

        // ---- Le snapshot déjà figé DOIT rester rigoureusement identique ----
        const afterSnap = await db
          .collection("financial_snapshots")
          .doc(result.snapshotId)
          .get();
        const afterTaxSnapshot = afterSnap.data()!.tax_snapshot;
        expect(afterTaxSnapshot).toEqual(frozenTaxSnapshot);
        expect(afterTaxSnapshot.total_tax_minor).toBe(frozenTotalTaxMinor);
        expect(afterTaxSnapshot.tax_version_ids).toEqual(["QC_GST_E2E_TEST_v1"]);
      } finally {
        await cleanupTaxConfigs("QC", ["GST_E2E_TEST"]);
      }
    }
  );
});
