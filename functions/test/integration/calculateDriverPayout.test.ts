// ---------------------------------------------------------------------------
// Test d'intégration — calculateDriverPayout + updatePayoutPolicyConfiguration
// (Phase 6, point 9 : versement chauffeur avec période de rétention
// configurable, jamais hardcodée, + soumission réelle au fournisseur via
// FakePaymentProvider quand le versement est immédiatement éligible).
//
// Couvre :
//   - agrégation de plusieurs financial_snapshots confirmed non inclus
//   - conversion amount (dollars, legacy) -> amount_minor (cents entiers)
//   - lecture de payout_policy_configs/default (valeurs par défaut de
//     bootstrap SI aucune config n'a encore été écrite par un admin)
//   - résolution de la période de rétention selon le profil du chauffeur
//     (nouveau chauffeur / chauffeur suspendu / chauffeur établi)
//   - statut initial correct (PENDING si rétention > 0h, ELIGIBLE si 0h +
//     compte connecté déjà présent) et soumission immédiate au fournisseur
//     dans ce dernier cas (FakePaymentProvider, status final PAID)
//   - marquage included_in_payout_id sur les snapshots agrégés (jamais
//     réutilisés par un appel suivant)
//   - refus si driverId manquant, ou si aucun snapshot éligible
//   - updatePayoutPolicyConfiguration : admin uniquement, écrit le document,
//     journalise un audit_log
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { ScheduledEvent } from "firebase-functions/v2/scheduler";
import { calculateDriverPayout, CalculateDriverPayoutRequest } from "../../src/functions/calculateDriverPayout";
import { processScheduledDriverPayouts } from "../../src/functions/processScheduledDriverPayouts";
import {
  updatePayoutPolicyConfiguration,
  UpdatePayoutPolicyConfigurationRequest,
} from "../../src/functions/updatePayoutPolicyConfiguration";
import { admin, db } from "../../src/lib/admin";
import { PayoutStatuses } from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";
import {
  cleanupMissionsWithPayments,
  seedMissionWithPayment,
  seedMovikBatchPayoutMode,
} from "../testUtils/payoutBatchFixture";

const DRIVER_ID = "payout_driver_001";
const OTHER_DRIVER_ID = "payout_driver_no_snapshot";
const ADMIN_ID = "payout_admin_001";
const NON_ADMIN_ID = "payout_stranger_001";

function buildAdminRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: { role } as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

// Option A : chaque snapshot a une mission dont le paiement actif est
// CAPTURÉ sans compte connecté (sinon il n'est pas versable par ce chemin).
const seededMissionIds = new Set<string>();
async function seedSnapshot(
  id: string,
  driverId: string,
  driverNetMissionEarnings: number,
  opts: { includedInPayoutId?: string | null; payment?: "captured" | "authorized" | "connect" | "none" } = {}
): Promise<void> {
  const missionId = `mission_for_${id}`;
  await db.collection("financial_snapshots").doc(id).set({
    snapshot_id: id,
    mission_id: missionId,
    driver_id: driverId,
    status: "confirmed",
    driver_net_mission_earnings: driverNetMissionEarnings,
    included_in_payout_id: opts.includedInPayoutId ?? null,
    created_at: admin.firestore.Timestamp.now(),
  });
  const payment = opts.payment ?? "captured";
  if (payment === "none") return;
  seededMissionIds.add(missionId);
  await seedMissionWithPayment(missionId, driverId, {
    status: payment === "authorized" ? "authorized" : "captured",
    connectedAccountId: payment === "connect" ? "acct_fake_connect" : null,
  });
}

async function seedDriverProfile(
  driverId: string,
  opts: { completedMissions?: number; suspended?: boolean; connectedAccountId?: string | null } = {}
): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    completed_missions: opts.completedMissions ?? 10,
    suspended_at: opts.suspended ? admin.firestore.Timestamp.now() : null,
    stripe_connected_account_id: opts.connectedAccountId ?? null,
    online_status: "online",
  });
}

async function cleanup(driverId: string): Promise<void> {
  const [snapshots, payouts, driverDoc, auditSnap] = await Promise.all([
    db.collection("financial_snapshots").where("driver_id", "==", driverId).get(),
    db.collection("driver_payouts").where("driver_id", "==", driverId).get(),
    db.collection("driver_profiles").doc(driverId).get(),
    db
      .collection("audit_logs")
      .where("source_function", "in", ["calculateDriverPayout", "submitDriverPayout"])
      .get(),
  ]);
  const batch = db.batch();
  snapshots.docs.forEach((d) => batch.delete(d.ref));
  await cleanupMissionsWithPayments([...seededMissionIds]);
  seededMissionIds.clear();
  const payoutIds = payouts.docs.map((d) => d.id);
  payouts.docs.forEach((d) => batch.delete(d.ref));
  if (driverDoc.exists) batch.delete(driverDoc.ref);
  auditSnap.docs.forEach((d) => {
    const targetId = d.data().target_id as string | undefined;
    // `calculateDriverPayout` action technique cible driverId ; `payout_created`
    // (évènement métier) et `payout_submitted` ciblent payoutId — les trois
    // doivent être nettoyés pour éviter toute fuite entre `it()`.
    if (targetId === driverId || (targetId && payoutIds.includes(targetId))) {
      batch.delete(d.ref);
    }
  });
  await batch.commit();
}

async function cleanupPayoutPolicy(): Promise<void> {
  await db.collection("payout_policy_configs").doc("default").delete();
  const auditSnap = await db
    .collection("audit_logs")
    .where("source_function", "==", "updatePayoutPolicyConfiguration")
    .get();
  const batch = db.batch();
  auditSnap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("calculateDriverPayout — agrégation, cents, rétention configurable", () => {
  beforeEach(async () => {
    setPaymentProviderForTesting(new FakePaymentProvider());
    // Option A (2026-10-27) : le chemin groupé n'existe qu'en mode movik_batch.
    await seedMovikBatchPayoutMode();
  });

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanup(DRIVER_ID);
    await cleanup(OTHER_DRIVER_ID);
    await cleanupPayoutPolicy();
  });

  it("agrège plusieurs snapshots confirmed et convertit le total en cents entiers", async () => {
    await seedDriverProfile(DRIVER_ID, { completedMissions: 50, connectedAccountId: null });
    await seedSnapshot("snap_agg_1", DRIVER_ID, 42.5);
    await seedSnapshot("snap_agg_2", DRIVER_ID, 17.25);

    const result = await calculateDriverPayout.run(
      buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
    );

    // 42.50 + 17.25 = 59.75 $ -> 5975 cents entiers, jamais un flottant.
    expect(result.amountMinor).toBe(5975);
    expect(Number.isInteger(result.amountMinor)).toBe(true);
    expect(result.payoutId).toBeTruthy();

    const payoutSnap = await db.collection("driver_payouts").doc(result.payoutId as string).get();
    expect(payoutSnap.exists).toBe(true);
    const payout = payoutSnap.data()!;
    expect(payout.amount_minor).toBe(5975);
    expect(typeof payout.amount).toBe("undefined"); // plus de champ legacy flottant

    // BLOC H (Tâche 4) — vérifie explicitement que l'événement métier
    // `payout_created` existe RÉELLEMENT (distinct de l'action technique
    // `calculateDriverPayout`), pas seulement une couverture indirecte.
    const businessAudit = await db
      .collection("audit_logs")
      .where("action", "==", "payout_created")
      .where("target_id", "==", result.payoutId)
      .get();
    expect(businessAudit.size).toBe(1);
    expect(businessAudit.docs[0].data().source_function).toBe("calculateDriverPayout");
    expect(businessAudit.docs[0].data().metadata.amountMinor).toBe(5975);
  });

  it("marque les snapshots agrégés avec included_in_payout_id (jamais réutilisés)", async () => {
    await seedDriverProfile(DRIVER_ID, { completedMissions: 50 });
    await seedSnapshot("snap_mark_1", DRIVER_ID, 10);

    const result = await calculateDriverPayout.run(
      buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
    );

    const snapAfter = await db.collection("financial_snapshots").doc("snap_mark_1").get();
    expect(snapAfter.data()!.included_in_payout_id).toBe(result.payoutId);

    // Un second appel ne doit RIEN trouver (snapshot déjà inclus).
    const secondResult = await calculateDriverPayout.run(
      buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
    );
    expect(secondResult.payoutId).toBeNull();
    expect(secondResult.amountMinor).toBe(0);
  });

  it("renvoie payoutId=null si aucun snapshot éligible n'existe pour ce chauffeur", async () => {
    const result = await calculateDriverPayout.run(
      buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: OTHER_DRIVER_ID })
    );
    expect(result.payoutId).toBeNull();
    expect(result.amountMinor).toBe(0);
  });

  // ---- Option A (2026-10-27) ----------------------------------------------
  it("option A : refuse (failed-precondition) en mode stripe_direct — Stripe vire à la capture", async () => {
    await db.doc("payout_policy_configs/default").set({ payout_mode: "stripe_direct" }, { merge: true });
    await seedDriverProfile(DRIVER_ID, { completedMissions: 50 });
    await seedSnapshot("snap_direct_1", DRIVER_ID, 10);

    await expect(
      calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
      )
    ).rejects.toThrow(/stripe_direct/);
    const snapAfter = await db.collection("financial_snapshots").doc("snap_direct_1").get();
    expect(snapAfter.data()!.included_in_payout_id).toBeNull();
    const payouts = await db.collection("driver_payouts").where("driver_id", "==", DRIVER_ID).get();
    expect(payouts.empty).toBe(true);
  });

  it("option A : un snapshot dont le paiement n'est pas capturé, ou a été viré par Connect, n'est jamais versé", async () => {
    await seedDriverProfile(DRIVER_ID, { completedMissions: 50 });
    await seedSnapshot("snap_mix_captured", DRIVER_ID, 20);
    await seedSnapshot("snap_mix_authorized", DRIVER_ID, 30, { payment: "authorized" });
    await seedSnapshot("snap_mix_connect", DRIVER_ID, 40, { payment: "connect" });
    await seedSnapshot("snap_mix_nopayment", DRIVER_ID, 50, { payment: "none" });

    const result = await calculateDriverPayout.run(
      buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
    );
    expect(result.amountMinor).toBe(2000);
    const payout = (await db.collection("driver_payouts").doc(result.payoutId as string).get()).data()!;
    expect(payout.financial_snapshot_ids).toEqual(["snap_mix_captured"]);
    for (const id of ["snap_mix_authorized", "snap_mix_connect", "snap_mix_nopayment"]) {
      const snap = await db.collection("financial_snapshots").doc(id).get();
      expect(snap.data()!.included_in_payout_id).toBeNull();
    }
  });

  it("option A : en mode stripe_direct, le cron ne promeut ni ne soumet aucun versement groupé", async () => {
    await db.doc("payout_policy_configs/default").set({ payout_mode: "stripe_direct" }, { merge: true });
    await seedDriverProfile(DRIVER_ID, { completedMissions: 50, connectedAccountId: "acct_fake_cron_direct" });
    const payoutId = "payout_direct_cron_001";
    const now = admin.firestore.Timestamp.now();
    await db.collection("driver_payouts").doc(payoutId).set({
      driver_id: DRIVER_ID,
      financial_snapshot_ids: [],
      amount_minor: 1000,
      currency: "CAD",
      status: PayoutStatuses.PENDING,
      payout_hold_period_hours: 0,
      payout_eligible_at: admin.firestore.Timestamp.fromMillis(now.toMillis() - 60_000),
      provider_payout_id: null,
      connected_account_id: "acct_fake_cron_direct",
      created_at: now,
      idempotency_key: `seed_${payoutId}`,
    });

    await (
      processScheduledDriverPayouts as unknown as { run: (e: ScheduledEvent) => Promise<void> }
    ).run({ scheduleTime: new Date().toISOString(), jobName: "test-direct" } as unknown as ScheduledEvent);

    const after = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
    expect(after.status).toBe(PayoutStatuses.PENDING);
    expect(after.provider_payout_id).toBeNull();
  });

  it("refuse (invalid-argument) si driverId est manquant", async () => {
    await expect(
      calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", {
          driverId: "" as unknown as string,
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (permission-denied) si l'appelant n'est pas admin/super_admin", async () => {
    await seedSnapshot("snap_perm_1", DRIVER_ID, 10);
    await expect(
      calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(NON_ADMIN_ID, "driver", { driverId: DRIVER_ID })
      )
    ).rejects.toThrow();
  });

  it(
    "chauffeur NOUVEAU (< 5 missions) : statut initial PENDING, payout_hold_period_hours = " +
      "new_driver_hold_period_hours de la politique par défaut (bootstrap = 168h)",
    async () => {
      await seedDriverProfile(DRIVER_ID, { completedMissions: 2 });
      await seedSnapshot("snap_new_1", DRIVER_ID, 30);

      const result = await calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
      );

      expect(result.status).toBe(PayoutStatuses.PENDING);
      const payout = (await db.collection("driver_payouts").doc(result.payoutId as string).get()).data()!;
      expect(payout.payout_hold_period_hours).toBe(168);
      expect(payout.status).toBe(PayoutStatuses.PENDING);
    }
  );

  it("chauffeur SUSPENDU : payout_hold_period_hours = risky_driver_hold_period_hours (bootstrap = 336h)", async () => {
    await seedDriverProfile(DRIVER_ID, { completedMissions: 50, suspended: true });
    await seedSnapshot("snap_risky_1", DRIVER_ID, 30);

    const result = await calculateDriverPayout.run(
      buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
    );

    const payout = (await db.collection("driver_payouts").doc(result.payoutId as string).get()).data()!;
    expect(payout.payout_hold_period_hours).toBe(336);
  });

  it(
    "respecte une politique ADMIN personnalisée (updatePayoutPolicyConfiguration) plutôt que le " +
      "bootstrap par défaut — vérifie que rien n'est hardcodé dans le calcul",
    async () => {
      await updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
          defaultHoldPeriodHours: 1,
          newDriverHoldPeriodHours: 2,
          riskyDriverHoldPeriodHours: 3,
        })
      );

      await seedDriverProfile(DRIVER_ID, { completedMissions: 50 }); // établi -> default
      await seedSnapshot("snap_custom_1", DRIVER_ID, 30);

      const result = await calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
      );

      const payout = (await db.collection("driver_payouts").doc(result.payoutId as string).get()).data()!;
      expect(payout.payout_hold_period_hours).toBe(1);
    }
  );

  it(
    "rétention nulle (0h) + compte connecté déjà présent : le versement démarre ELIGIBLE et " +
      "est immédiatement soumis au FakePaymentProvider (statut final PAID)",
    async () => {
      await updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
          defaultHoldPeriodHours: 0,
          newDriverHoldPeriodHours: 0,
          riskyDriverHoldPeriodHours: 0,
        })
      );
      await seedDriverProfile(DRIVER_ID, {
        completedMissions: 50,
        connectedAccountId: "fake_acct_seeded",
      });
      await seedSnapshot("snap_immediate_1", DRIVER_ID, 30);

      const result = await calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
      );

      expect(result.success).toBe(true);
      expect(result.status).toBe(PayoutStatuses.PAID);

      const payout = (await db.collection("driver_payouts").doc(result.payoutId as string).get()).data()!;
      expect(payout.status).toBe(PayoutStatuses.PAID);
      expect(payout.provider_payout_id).toBeTruthy();
      expect(payout.paid_at).toBeTruthy();

      // BLOC H (Tâche 4) — vérifie explicitement que `payout_submitted`
      // (journalisé par submitDriverPayout(), déclenché automatiquement ici
      // car le versement démarre ELIGIBLE) existe RÉELLEMENT.
      const submittedAudit = await db
        .collection("audit_logs")
        .where("action", "==", "payout_submitted")
        .where("target_id", "==", result.payoutId)
        .get();
      expect(submittedAudit.size).toBe(1);
      expect(submittedAudit.docs[0].data().source_function).toBe("submitDriverPayout");
    }
  );

  it(
    "rétention nulle (0h) MAIS sans compte connecté : reste en PENDING (jamais de tentative " +
      "d'appel fournisseur sans connected_account_id)",
    async () => {
      await updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
          defaultHoldPeriodHours: 0,
          newDriverHoldPeriodHours: 0,
          riskyDriverHoldPeriodHours: 0,
        })
      );
      await seedDriverProfile(DRIVER_ID, { completedMissions: 50, connectedAccountId: null });
      await seedSnapshot("snap_no_acct_1", DRIVER_ID, 30);

      const result = await calculateDriverPayout.run(
        buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
      );

      expect(result.status).toBe(PayoutStatuses.PENDING);
    }
  );
});

describe("updatePayoutPolicyConfiguration", () => {
  afterEach(async () => {
    await cleanupPayoutPolicy();
  });

  it("écrit payout_policy_configs/default et journalise un audit_log (admin uniquement)", async () => {
    const result = await updatePayoutPolicyConfiguration.run(
      buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "super_admin", {
        defaultHoldPeriodHours: 48,
        newDriverHoldPeriodHours: 120,
        riskyDriverHoldPeriodHours: 240,
      })
    );
    expect(result.success).toBe(true);

    const configSnap = await db.collection("payout_policy_configs").doc("default").get();
    expect(configSnap.exists).toBe(true);
    const config = configSnap.data()!;
    expect(config.default_hold_period_hours).toBe(48);
    expect(config.new_driver_hold_period_hours).toBe(120);
    expect(config.risky_driver_hold_period_hours).toBe(240);
    expect(config.updated_by_user_id).toBe(ADMIN_ID);
  });

  it(
    "BLOC H (Tâche 2/4) — journalise explicitement l'événement métier `payout_policy_changed` avec " +
      "old/new configuration, effective_at, configuration id, timestamp et correlation_id — SANS " +
      "ancienne configuration au premier appel (aucun document préexistant), PUIS avec l'ancienne " +
      "configuration correctement capturée lors d'un second appel qui la modifie",
    async () => {
      // ---- Premier appel : aucun document payout_policy_configs/default
      // préexistant -> oldConfiguration doit être explicitement null.
      await updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
          defaultHoldPeriodHours: 10,
          newDriverHoldPeriodHours: 20,
          riskyDriverHoldPeriodHours: 30,
          correlationId: "corr_policy_first",
        })
      );

      const firstAudit = await db
        .collection("audit_logs")
        .where("action", "==", "payout_policy_changed")
        .where("metadata.correlationId", "==", "corr_policy_first")
        .get();
      expect(firstAudit.size).toBe(1);
      const firstEntry = firstAudit.docs[0].data();
      expect(firstEntry.actor_user_id).toBe(ADMIN_ID); // actor admin
      expect(firstEntry.source_function).toBe("updatePayoutPolicyConfiguration");
      expect(firstEntry.metadata.oldConfiguration).toBeNull(); // ancienne config absente
      expect(firstEntry.metadata.newConfiguration).toEqual({
        defaultHoldPeriodHours: 10,
        newDriverHoldPeriodHours: 20,
        riskyDriverHoldPeriodHours: 30,
        payoutMode: "stripe_direct",
      });
      expect(firstEntry.metadata.effectiveAt).toBeTruthy();
      expect(firstEntry.metadata.configurationId).toBe("payout_policy_configs/default");
      expect(firstEntry.metadata.timestamp).toBeTruthy();
      expect(firstEntry.metadata.correlationId).toBe("corr_policy_first");

      // ---- Second appel : modifie la configuration déjà existante ->
      // oldConfiguration doit refléter fidèlement les valeurs du PREMIER appel.
      await updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
          defaultHoldPeriodHours: 15,
          newDriverHoldPeriodHours: 25,
          riskyDriverHoldPeriodHours: 35,
          correlationId: "corr_policy_second",
        })
      );

      const secondAudit = await db
        .collection("audit_logs")
        .where("action", "==", "payout_policy_changed")
        .where("metadata.correlationId", "==", "corr_policy_second")
        .get();
      expect(secondAudit.size).toBe(1);
      const secondEntry = secondAudit.docs[0].data();
      expect(secondEntry.metadata.oldConfiguration).toEqual({
        defaultHoldPeriodHours: 10,
        newDriverHoldPeriodHours: 20,
        riskyDriverHoldPeriodHours: 30,
        payoutMode: "stripe_direct",
      });
      expect(secondEntry.metadata.newConfiguration).toEqual({
        defaultHoldPeriodHours: 15,
        newDriverHoldPeriodHours: 25,
        riskyDriverHoldPeriodHours: 35,
        payoutMode: "stripe_direct",
      });
    }
  );

  it("refuse (permission-denied) si l'appelant n'est pas admin/super_admin", async () => {
    await expect(
      updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(NON_ADMIN_ID, "customer", {
          defaultHoldPeriodHours: 1,
          newDriverHoldPeriodHours: 1,
          riskyDriverHoldPeriodHours: 1,
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (invalid-argument) une valeur négative", async () => {
    await expect(
      updatePayoutPolicyConfiguration.run(
        buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
          defaultHoldPeriodHours: -1,
          newDriverHoldPeriodHours: 1,
          riskyDriverHoldPeriodHours: 1,
        })
      )
    ).rejects.toThrow();
  });
});
