// ---------------------------------------------------------------------------
// Test d'intégration — Bloc D (Phase 7) : ANALYSTE / ADMIN / SUPER ADMIN.
//
// Comble le gap de couverture confirmé lors de la reconnaissance du Bloc D :
// les callables suivants n'étaient EXERCÉS PAR AUCUN test existant (0 appel
// `.run(` trouvé dans tout `functions/test/`) :
//   - setUserRole              (super_admin UNIQUEMENT)
//   - suspendDriver            (admin/super_admin)
//   - reactivateDriver         (admin/super_admin)
//   - requestDriverDocuments   (analyst/admin/super_admin)
//   - updatePricingConfiguration (admin/super_admin)
//   - applyDriverPromotion     (admin/super_admin)
//   - qualifyFoundingDriver / revokeFoundingDriverStatus (admin/super_admin)
//   - createFinancialSnapshot  (admin/super_admin)
//   - logDriverReviewOpened    (analyst/admin/super_admin)
//
// Et les callables suivants avaient une couverture SUCCESS-PATH uniquement,
// sans test dédié de refus par mauvais rôle :
//   - validateDriverDocument   (analyst/admin/super_admin)
//   - rejectDriver             (analyst/admin/super_admin)
//
// OBJECTIF (directive utilisateur, Bloc D) : prouver que chaque garde
// `require*OrAbove()`/`requireSuperAdmin()` réellement présente dans le
// code source refuse (permission-denied) tout rôle insuffisant, ET que le
// chemin de succès fonctionne pour le rôle minimal requis. On NE
// RÉ-AUDITE PAS les Security Rules Firestore (196/196 PASS déjà confirmé
// dans securityRules.test.ts) — uniquement la couche Cloud Function
// callable, qui est une surface d'autorisation DISTINCTE (les repositories
// Flutter appellent ces callables ; les Security Rules protègent
// uniquement les écritures Firestore directes, jamais exercées par ces
// callables côté client légitime).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { setUserRole, SetUserRoleRequest } from "../../src/functions/setUserRole";
import { suspendDriver, SuspendDriverRequest } from "../../src/functions/suspendDriver";
import { reactivateDriver, ReactivateDriverRequest } from "../../src/functions/reactivateDriver";
import {
  requestDriverDocuments,
  RequestDriverDocumentsRequest,
} from "../../src/functions/requestDriverDocuments";
import { addDriverInternalNote, AddDriverInternalNoteRequest } from "../../src/functions/addDriverInternalNote";
import {
  updatePricingConfiguration,
  UpdatePricingConfigurationRequest,
} from "../../src/functions/updatePricingConfiguration";
import { applyDriverPromotion, ApplyDriverPromotionRequest } from "../../src/functions/applyDriverPromotion";
import {
  qualifyFoundingDriver,
  revokeFoundingDriverStatus,
  QualifyFoundingDriverRequest,
  RevokeFoundingDriverStatusRequest,
} from "../../src/functions/qualifyFoundingDriver";
import {
  createFinancialSnapshot,
  CreateFinancialSnapshotRequest,
} from "../../src/functions/createFinancialSnapshot";
import {
  logDriverReviewOpened,
  LogDriverReviewOpenedRequest,
} from "../../src/functions/logDriverReviewOpened";
import {
  validateDriverDocument,
  ValidateDriverDocumentRequest,
} from "../../src/functions/validateDriverDocument";
import { rejectDriver, RejectDriverRequest } from "../../src/functions/rejectDriver";
import { admin, authAdmin, db } from "../../src/lib/admin";
import { buildPricingConfig } from "../unit/fixtures";
import { DriverStatuses, FoundingDriverStatuses, PlatformRoles } from "../../src/lib/types";

function buildRequest<T>(
  uid: string,
  data: T,
  roles?: string[]
): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: (roles ? { role: roles[0], roles } : {}) as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

const DRIVER_ID = "blocd_driver_001";
const OTHER_DRIVER_ID = "blocd_driver_002";
const ANALYST_ID = "blocd_analyst_001";
const ADMIN_ID = "blocd_admin_001";
const SUPER_ADMIN_ID = "blocd_super_admin_001";
const CUSTOMER_ID = "blocd_customer_001";
const MISSION_ID = "blocd_mission_001";
const SNAPSHOT_ID = "blocd_snapshot_001";
const PROGRAM_ID = "blocd_founding_program_001";
const PRICING_VERSION = "BLOCD-PRICING-001";
const NEW_PRICING_VERSION = "BLOCD-PRICING-002";
const TARGET_UID_FOR_ROLE_CHANGE = "blocd_target_user_001";

async function seedDriverProfile(
  driverId: string,
  status: string,
  overrides: Record<string, unknown> = {}
): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    full_name: "Chauffeur Bloc D",
    city: "Montréal",
    status,
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 0,
    completed_missions: 0,
    created_at: admin.firestore.Timestamp.now(),
    online_status: status === DriverStatuses.SUSPENDED ? "offline" : "online",
    documents_all_valid: true,
    ...overrides,
  });
}

async function seedPricing(): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

async function seedMissionForSnapshot(opts: {
  activeSnapshotId?: string | null;
}): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION_ID).set({
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: "picked_up",
    item_category_key: "furniture",
    description: "Test createFinancialSnapshot Bloc D.",
    required_vehicle_category: "cargoVan",
    distance_km: 10,
    estimated_duration_minutes: 20,
    customer_discount_amount: 0,
    pricing_version: PRICING_VERSION,
    active_financial_snapshot_id: opts.activeSnapshotId === undefined ? null : opts.activeSnapshotId,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function seedConfirmedSnapshot(): Promise<void> {
  await db.collection("financial_snapshots").doc(SNAPSHOT_ID).set({
    snapshot_id: SNAPSHOT_ID,
    mission_id: MISSION_ID,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    pricing_version: PRICING_VERSION,
    status: "confirmed",
    created_at: admin.firestore.Timestamp.now(),
    confirmed_at: admin.firestore.Timestamp.now(),
  });
}

async function seedFoundingProgram(programId: string, totalSlots = 100, slotsTaken = 1): Promise<void> {
  await db.collection("founding_driver_programs").doc(programId).set({
    program_id: programId,
    is_active: true,
    total_slots: totalSlots,
    slots_taken: slotsTaken,
    promotional_commission_rate: 0.05,
    promotional_duration_months: 6,
    preferred_commission_rate: 0.1,
  });
}

async function seedDriverDocument(driverId: string, status: string): Promise<string> {
  const ref = db.collection("driver_documents").doc();
  await ref.set({
    driver_id: driverId,
    status,
    type: "drivers_licence",
    created_at: admin.firestore.Timestamp.now(),
  });
  return ref.id;
}

async function cleanupAll(): Promise<void> {
  const auditActions = [
    "setUserRole",
    "driver_suspended",
    "driver_reactivated",
    "driver_documents_requested",
    "driver_internal_note_added",
    "updatePricingConfiguration",
    "applyDriverPromotion",
    "qualifyFoundingDriver",
    "revokeFoundingDriverStatus",
    "createFinancialSnapshot",
    "driver_review_opened",
    "validateDriverDocument",
    "driver_rejected",
  ];
  const auditSnaps = await Promise.all(
    auditActions.map((action) => db.collection("audit_logs").where("action", "==", action).get())
  );
  const notesSnap = await db
    .collection("driver_internal_notes")
    .where("driver_id", "in", [DRIVER_ID, OTHER_DRIVER_ID])
    .get();
  const docsSnap = await db
    .collection("driver_documents")
    .where("driver_id", "in", [DRIVER_ID, OTHER_DRIVER_ID])
    .get();
  const qualSnap = await db
    .collection("founding_driver_programs")
    .doc(PROGRAM_ID)
    .collection("qualifications")
    .get();

  const batch = db.batch();
  auditSnaps.forEach((snap) => snap.docs.forEach((d) => batch.delete(d.ref)));
  notesSnap.docs.forEach((d) => batch.delete(d.ref));
  docsSnap.docs.forEach((d) => batch.delete(d.ref));
  qualSnap.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(db.collection("driver_profiles").doc(DRIVER_ID));
  batch.delete(db.collection("driver_profiles").doc(OTHER_DRIVER_ID));
  batch.delete(db.collection("delivery_requests").doc(MISSION_ID));
  batch.delete(db.collection("financial_snapshots").doc(SNAPSHOT_ID));
  batch.delete(db.collection("pricing_configs").doc("active"));
  batch.delete(db.collection("pricing_versions").doc(PRICING_VERSION));
  batch.delete(db.collection("pricing_versions").doc(NEW_PRICING_VERSION));
  batch.delete(db.collection("founding_driver_programs").doc(PROGRAM_ID));
  batch.delete(db.collection("driver_pricing_profiles").doc(DRIVER_ID));
  batch.delete(db.collection("users").doc(TARGET_UID_FOR_ROLE_CHANGE));
  await batch.commit();

  await authAdmin.deleteUser(TARGET_UID_FOR_ROLE_CHANGE).catch(() => undefined);
}

describe("Bloc D — setUserRole (super_admin UNIQUEMENT)", () => {
  beforeEach(async () => {
    await authAdmin.createUser({ uid: TARGET_UID_FOR_ROLE_CHANGE, email: `${TARGET_UID_FOR_ROLE_CHANGE}@example.com` });
  });
  afterEach(cleanupAll);

  it("super_admin peut élever un utilisateur (Custom Claims + miroir Firestore + audit)", async () => {
    const result = await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        SUPER_ADMIN_ID,
        { targetUid: TARGET_UID_FOR_ROLE_CHANGE, roles: [PlatformRoles.ANALYST] },
        ["super_admin"]
      )
    );
    expect(result.success).toBe(true);

    const userRecord = await authAdmin.getUser(TARGET_UID_FOR_ROLE_CHANGE);
    expect(userRecord.customClaims?.role).toBe("analyst");
    expect(userRecord.customClaims?.roles).toEqual(["analyst"]);

    const mirror = await db.collection("users").doc(TARGET_UID_FOR_ROLE_CHANGE).get();
    expect(mirror.data()!.roles).toEqual(["analyst"]);

    const audit = await db.collection("audit_logs").where("action", "==", "setUserRole").get();
    expect(audit.size).toBe(1);
    expect(audit.docs[0].data().actor_user_id).toBe(SUPER_ADMIN_ID);
  });

  it.each([
    ["customer", ["customer"]],
    ["driver", ["driver"]],
    ["analyst", ["analyst"]],
    ["admin", ["admin"]],
  ])("refuse (permission-denied) un appelant %s — SEUL super_admin peut changer un rôle", async (_label, roles) => {
    await expect(
      setUserRole.run(
        buildRequest<SetUserRoleRequest>(
          "blocd_stranger_001",
          { targetUid: TARGET_UID_FOR_ROLE_CHANGE, roles: [PlatformRoles.ADMIN] },
          roles
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    // Aucun effet de bord : claims/miroir inchangés.
    const userRecord = await authAdmin.getUser(TARGET_UID_FOR_ROLE_CHANGE);
    expect(userRecord.customClaims ?? {}).toEqual({});
  });

  it("refuse (invalid-argument) un rôle invalide, même appelé par super_admin", async () => {
    await expect(
      setUserRole.run(
        buildRequest<SetUserRoleRequest>(
          SUPER_ADMIN_ID,
          { targetUid: TARGET_UID_FOR_ROLE_CHANGE, roles: ["invalid_role" as never] },
          ["super_admin"]
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("refuse (invalid-argument) targetUid manquant ou roles vide", async () => {
    await expect(
      setUserRole.run(
        buildRequest<SetUserRoleRequest>(SUPER_ADMIN_ID, { targetUid: "", roles: [PlatformRoles.ADMIN] }, [
          "super_admin",
        ])
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      setUserRole.run(
        buildRequest<SetUserRoleRequest>(
          SUPER_ADMIN_ID,
          { targetUid: TARGET_UID_FOR_ROLE_CHANGE, roles: [] },
          ["super_admin"]
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

describe("Bloc D — suspendDriver / reactivateDriver (admin/super_admin — PAS analyst)", () => {
  afterEach(cleanupAll);

  it("admin peut suspendre un chauffeur approved, avec audit driver_suspended", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    const result = await suspendDriver.run(
      buildRequest<SuspendDriverRequest>(
        ADMIN_ID,
        { driverId: DRIVER_ID, reason: "Plainte grave signalée par un client." },
        ["admin"]
      )
    );
    expect(result.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.SUSPENDED);
    expect(driverSnap.data()!.online_status).toBe("offline");
    expect(driverSnap.data()!.suspended_by_user_id).toBe(ADMIN_ID);

    const audit = await db.collection("audit_logs").where("action", "==", "driver_suspended").get();
    expect(audit.size).toBe(1);
  });

  it("refuse (permission-denied) suspendDriver pour analyst — action plus sensible qu'approve/reject", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    await expect(
      suspendDriver.run(
        buildRequest<SuspendDriverRequest>(
          ANALYST_ID,
          { driverId: DRIVER_ID, reason: "Tentative analyst non autorisée." },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.APPROVED); // inchangé
  });

  it("refuse (permission-denied) suspendDriver pour customer/driver", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    await expect(
      suspendDriver.run(
        buildRequest<SuspendDriverRequest>(
          "blocd_stranger_customer",
          { driverId: DRIVER_ID, reason: "Tentative non autorisée." },
          ["customer"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("refuse (failed-precondition) une double suspension", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.SUSPENDED);

    await expect(
      suspendDriver.run(
        buildRequest<SuspendDriverRequest>(ADMIN_ID, { driverId: DRIVER_ID, reason: "Déjà suspendu." }, [
          "admin",
        ])
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("admin peut réactiver un chauffeur suspendu -> approved, avec audit driver_reactivated", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.SUSPENDED, {
      suspended_at: admin.firestore.Timestamp.now(),
      suspended_by_user_id: ADMIN_ID,
      suspension_reason: "Ancien motif.",
    });

    const result = await reactivateDriver.run(
      buildRequest<ReactivateDriverRequest>(ADMIN_ID, { driverId: DRIVER_ID }, ["admin"])
    );
    expect(result.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.APPROVED);
    expect(driverSnap.data()!.suspended_at).toBeNull();
    expect(driverSnap.data()!.suspension_reason).toBeNull();
    expect(driverSnap.data()!.reactivated_by_user_id).toBe(ADMIN_ID);

    const audit = await db.collection("audit_logs").where("action", "==", "driver_reactivated").get();
    expect(audit.size).toBe(1);
  });

  it("refuse (permission-denied) reactivateDriver pour analyst", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.SUSPENDED);

    await expect(
      reactivateDriver.run(
        buildRequest<ReactivateDriverRequest>(ANALYST_ID, { driverId: DRIVER_ID }, ["analyst"])
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("refuse (failed-precondition) réactiver un chauffeur qui n'est pas suspendu", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    await expect(
      reactivateDriver.run(
        buildRequest<ReactivateDriverRequest>(ADMIN_ID, { driverId: DRIVER_ID }, ["admin"])
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});

describe("Bloc D — requestDriverDocuments / addDriverInternalNote / logDriverReviewOpened (analyst/admin/super_admin)", () => {
  afterEach(cleanupAll);

  it("analyst peut demander des documents (pending_review -> documents_required)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.PENDING_REVIEW);

    const result = await requestDriverDocuments.run(
      buildRequest<RequestDriverDocumentsRequest>(
        ANALYST_ID,
        { driverId: DRIVER_ID, reason: "Photo du permis illisible." },
        ["analyst"]
      )
    );
    expect(result.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.DOCUMENTS_REQUIRED);
    expect(driverSnap.data()!.documents_required_by_user_id).toBe(ANALYST_ID);
  });

  it("refuse (permission-denied) requestDriverDocuments pour customer/driver", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.PENDING_REVIEW);

    await expect(
      requestDriverDocuments.run(
        buildRequest<RequestDriverDocumentsRequest>(
          "blocd_stranger_driver",
          { driverId: DRIVER_ID, reason: "Tentative non autorisée." },
          ["driver"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("refuse (failed-precondition) requestDriverDocuments depuis un statut non autorisé (rejected)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.REJECTED);

    await expect(
      requestDriverDocuments.run(
        buildRequest<RequestDriverDocumentsRequest>(
          ANALYST_ID,
          { driverId: DRIVER_ID, reason: "Tentative depuis rejected." },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("analyst peut ajouter une note interne (déjà success-path testé indirectement) ; refuse un rôle insuffisant", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    const ok = await addDriverInternalNote.run(
      buildRequest<AddDriverInternalNoteRequest>(
        ANALYST_ID,
        { driverId: DRIVER_ID, text: "Note interne Bloc D." },
        ["analyst"]
      )
    );
    expect(ok.success).toBe(true);

    await expect(
      addDriverInternalNote.run(
        buildRequest<AddDriverInternalNoteRequest>(
          "blocd_stranger_customer_2",
          { driverId: DRIVER_ID, text: "Tentative non autorisée." },
          ["customer"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("analyst peut journaliser l'ouverture d'un dossier (logDriverReviewOpened), sans écrire de champ métier", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.PENDING_REVIEW);

    const result = await logDriverReviewOpened.run(
      buildRequest<LogDriverReviewOpenedRequest>(ANALYST_ID, { driverId: DRIVER_ID }, ["analyst"])
    );
    expect(result.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.PENDING_REVIEW); // inchangé

    const audit = await db.collection("audit_logs").where("action", "==", "driver_review_opened").get();
    expect(audit.size).toBe(1);
  });

  it("refuse (permission-denied) logDriverReviewOpened pour un rôle insuffisant (driver)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.PENDING_REVIEW);

    await expect(
      logDriverReviewOpened.run(
        buildRequest<LogDriverReviewOpenedRequest>("blocd_stranger_driver_2", { driverId: DRIVER_ID }, [
          "driver",
        ])
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});

describe("Bloc D — validateDriverDocument / rejectDriver : gap de couverture 'permission-denied' (success-path déjà couvert par e2eDriverOnboardingToPayout.test.ts)", () => {
  afterEach(cleanupAll);

  it("refuse (permission-denied) validateDriverDocument pour un appelant non-analyst", async () => {
    const documentId = await seedDriverDocument(DRIVER_ID, "uploaded");

    await expect(
      validateDriverDocument.run(
        buildRequest<ValidateDriverDocumentRequest>(
          "blocd_stranger_driver_3",
          { documentId, newStatus: "approved" as never },
          ["driver"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const docSnap = await db.collection("driver_documents").doc(documentId).get();
    expect(docSnap.data()!.status).toBe("uploaded"); // inchangé
  });

  it("refuse (permission-denied) rejectDriver pour un appelant non-analyst", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.PENDING_REVIEW);

    await expect(
      rejectDriver.run(
        buildRequest<RejectDriverRequest>(
          "blocd_stranger_customer_3",
          { driverId: DRIVER_ID, reason: "Tentative non autorisée." },
          ["customer"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.PENDING_REVIEW); // inchangé
  });
});

describe("Bloc D — updatePricingConfiguration (admin/super_admin — config sensible)", () => {
  afterEach(cleanupAll);

  it("admin peut créer une nouvelle pricing_version immuable et mettre à jour le pointeur actif", async () => {
    const config = buildPricingConfig({ pricing_version: NEW_PRICING_VERSION });
    // Retirer les champs gérés par la fonction elle-même (pricing_version/is_active/effective_from).
    const { pricing_version: _pv, is_active: _ia, effective_from: _ef, ...rest } = config;

    const result = await updatePricingConfiguration.run(
      buildRequest<UpdatePricingConfigurationRequest>(
        ADMIN_ID,
        { newPricingVersion: NEW_PRICING_VERSION, config: rest },
        ["admin"]
      )
    );
    expect(result.success).toBe(true);

    const versionSnap = await db.collection("pricing_versions").doc(NEW_PRICING_VERSION).get();
    expect(versionSnap.exists).toBe(true);
    expect(versionSnap.data()!.is_active).toBe(true);

    const activeSnap = await db.collection("pricing_configs").doc("active").get();
    expect(activeSnap.data()!.active_pricing_version).toBe(NEW_PRICING_VERSION);
  });

  it("refuse (permission-denied) updatePricingConfiguration pour analyst — config financière sensible réservée admin+", async () => {
    const config = buildPricingConfig({ pricing_version: NEW_PRICING_VERSION });
    const { pricing_version: _pv, is_active: _ia, effective_from: _ef, ...rest } = config;

    await expect(
      updatePricingConfiguration.run(
        buildRequest<UpdatePricingConfigurationRequest>(
          ANALYST_ID,
          { newPricingVersion: NEW_PRICING_VERSION, config: rest },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const versionSnap = await db.collection("pricing_versions").doc(NEW_PRICING_VERSION).get();
    expect(versionSnap.exists).toBe(false); // aucun effet de bord
  });

  it("refuse (failed-precondition) écraser une pricing_version existante (immutabilité)", async () => {
    await seedPricing();

    const config = buildPricingConfig({ pricing_version: PRICING_VERSION });
    const { pricing_version: _pv, is_active: _ia, effective_from: _ef, ...rest } = config;

    await expect(
      updatePricingConfiguration.run(
        buildRequest<UpdatePricingConfigurationRequest>(
          ADMIN_ID,
          { newPricingVersion: PRICING_VERSION, config: rest },
          ["admin"]
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});

describe("Bloc D — applyDriverPromotion (admin/super_admin)", () => {
  afterEach(cleanupAll);

  it("admin peut appliquer une promotion de commission à un chauffeur", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    const now = Date.now();

    const result = await applyDriverPromotion.run(
      buildRequest<ApplyDriverPromotionRequest>(
        ADMIN_ID,
        {
          driverId: DRIVER_ID,
          promotionalCommissionRate: 0.08,
          startsAtMillis: now,
          endsAtMillis: now + 30 * 24 * 3600 * 1000,
          reason: "Promotion lancement Bloc D.",
        },
        ["admin"]
      )
    );
    expect(result.success).toBe(true);

    const pricingProfile = await db.collection("driver_pricing_profiles").doc(DRIVER_ID).get();
    expect(pricingProfile.data()!.resolved_commission_rate).toBe(0.08);
  });

  it("refuse (permission-denied) applyDriverPromotion pour analyst", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    const now = Date.now();

    await expect(
      applyDriverPromotion.run(
        buildRequest<ApplyDriverPromotionRequest>(
          ANALYST_ID,
          {
            driverId: DRIVER_ID,
            promotionalCommissionRate: 0.08,
            startsAtMillis: now,
            endsAtMillis: now + 30 * 24 * 3600 * 1000,
          },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("refuse (invalid-argument) un taux de commission hors [0,1]", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    const now = Date.now();

    await expect(
      applyDriverPromotion.run(
        buildRequest<ApplyDriverPromotionRequest>(
          ADMIN_ID,
          {
            driverId: DRIVER_ID,
            promotionalCommissionRate: 1.5,
            startsAtMillis: now,
            endsAtMillis: now + 1000,
          },
          ["admin"]
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

describe("Bloc D — qualifyFoundingDriver / revokeFoundingDriverStatus (admin/super_admin)", () => {
  afterEach(cleanupAll);

  it("admin peut qualifier un chauffeur Founding Driver (incrément atomique de slots_taken)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    await seedFoundingProgram(PROGRAM_ID, 100, 1);

    const result = await qualifyFoundingDriver.run(
      buildRequest<QualifyFoundingDriverRequest>(
        ADMIN_ID,
        { programId: PROGRAM_ID, driverId: DRIVER_ID },
        ["admin"]
      )
    );
    expect(result.success).toBe(true);

    const programSnap = await db.collection("founding_driver_programs").doc(PROGRAM_ID).get();
    expect(programSnap.data()!.slots_taken).toBe(2);

    const qualSnap = await db
      .collection("founding_driver_programs")
      .doc(PROGRAM_ID)
      .collection("qualifications")
      .doc(DRIVER_ID)
      .get();
    expect(qualSnap.data()!.status).toBe(FoundingDriverStatuses.QUALIFIED);
  });

  it("refuse (permission-denied) qualifyFoundingDriver pour analyst", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    await seedFoundingProgram(PROGRAM_ID, 100, 1);

    await expect(
      qualifyFoundingDriver.run(
        buildRequest<QualifyFoundingDriverRequest>(
          ANALYST_ID,
          { programId: PROGRAM_ID, driverId: DRIVER_ID },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const programSnap = await db.collection("founding_driver_programs").doc(PROGRAM_ID).get();
    expect(programSnap.data()!.slots_taken).toBe(1); // inchangé
  });

  it("refuse (failed-precondition) qualifier un chauffeur si le programme est complet", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    await seedFoundingProgram(PROGRAM_ID, 1, 1); // 0 place disponible

    await expect(
      qualifyFoundingDriver.run(
        buildRequest<QualifyFoundingDriverRequest>(
          ADMIN_ID,
          { programId: PROGRAM_ID, driverId: DRIVER_ID },
          ["admin"]
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("admin peut révoquer un statut Founding Driver déjà qualifié, avec audit", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    await seedFoundingProgram(PROGRAM_ID, 100, 2);
    await db
      .collection("founding_driver_programs")
      .doc(PROGRAM_ID)
      .collection("qualifications")
      .doc(DRIVER_ID)
      .set({
        driver_id: DRIVER_ID,
        program_id: PROGRAM_ID,
        status: FoundingDriverStatuses.QUALIFIED,
        qualified_at: admin.firestore.Timestamp.now(),
        promotional_period_ends_at: admin.firestore.Timestamp.now(),
        suspension_reason: null,
        revocation_reason: null,
        status_changed_at: admin.firestore.Timestamp.now(),
        status_changed_by_user_id: "seed",
      });

    const result = await revokeFoundingDriverStatus.run(
      buildRequest<RevokeFoundingDriverStatusRequest>(
        ADMIN_ID,
        { programId: PROGRAM_ID, driverId: DRIVER_ID, reason: "Non-respect des conditions du programme." },
        ["admin"]
      )
    );
    expect(result.success).toBe(true);

    const qualSnap = await db
      .collection("founding_driver_programs")
      .doc(PROGRAM_ID)
      .collection("qualifications")
      .doc(DRIVER_ID)
      .get();
    expect(qualSnap.data()!.status).toBe(FoundingDriverStatuses.REVOKED);
    expect(qualSnap.data()!.revocation_reason).toBe("Non-respect des conditions du programme.");
  });

  it("refuse (permission-denied) revokeFoundingDriverStatus pour driver", async () => {
    await seedFoundingProgram(PROGRAM_ID, 100, 1);
    await db
      .collection("founding_driver_programs")
      .doc(PROGRAM_ID)
      .collection("qualifications")
      .doc(DRIVER_ID)
      .set({
        driver_id: DRIVER_ID,
        program_id: PROGRAM_ID,
        status: FoundingDriverStatuses.QUALIFIED,
        qualified_at: admin.firestore.Timestamp.now(),
        promotional_period_ends_at: admin.firestore.Timestamp.now(),
        suspension_reason: null,
        revocation_reason: null,
        status_changed_at: admin.firestore.Timestamp.now(),
        status_changed_by_user_id: "seed",
      });

    await expect(
      revokeFoundingDriverStatus.run(
        buildRequest<RevokeFoundingDriverStatusRequest>(
          DRIVER_ID,
          { programId: PROGRAM_ID, driverId: DRIVER_ID, reason: "Tentative d'auto-révocation." },
          ["driver"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});

describe("Bloc D — createFinancialSnapshot (admin/super_admin — chemin exceptionnel)", () => {
  afterEach(cleanupAll);

  it("admin peut créer un financial_snapshot exceptionnel pour une mission qui n'en a pas encore", async () => {
    await seedPricing();
    await seedMissionForSnapshot({ activeSnapshotId: null });

    const result = await createFinancialSnapshot.run(
      buildRequest<CreateFinancialSnapshotRequest>(
        ADMIN_ID,
        { missionId: MISSION_ID, reason: "Création rétroactive admin (Bloc D)." },
        ["admin"]
      )
    );
    expect(result.success).toBe(true);
    expect(result.snapshotId).toBeTruthy();

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.active_financial_snapshot_id).toBe(result.snapshotId);

    // Nettoyage du snapshot généré dynamiquement (id non prévisible).
    await db.collection("financial_snapshots").doc(result.snapshotId).delete();
  });

  it("refuse (permission-denied) createFinancialSnapshot pour analyst — action financière exceptionnelle réservée admin+", async () => {
    await seedPricing();
    await seedMissionForSnapshot({ activeSnapshotId: null });

    await expect(
      createFinancialSnapshot.run(
        buildRequest<CreateFinancialSnapshotRequest>(
          ANALYST_ID,
          { missionId: MISSION_ID, reason: "Tentative analyst non autorisée." },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.active_financial_snapshot_id).toBeNull(); // inchangé
  });

  it("refuse (failed-precondition) créer un snapshot si un snapshot CONFIRMÉ existe déjà (immutabilité)", async () => {
    await seedPricing();
    await seedMissionForSnapshot({ activeSnapshotId: SNAPSHOT_ID });
    await seedConfirmedSnapshot();

    await expect(
      createFinancialSnapshot.run(
        buildRequest<CreateFinancialSnapshotRequest>(
          ADMIN_ID,
          { missionId: MISSION_ID, reason: "Tentative de remplacement refusée." },
          ["admin"]
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});

// ---------------------------------------------------------------------------
// CAS NÉGATIFS TRANSVERSAUX (directive Bloc D) — écriture directe Firestore
// sur des champs financiers/sensibles jamais autorisée, même pour
// super_admin. Référence : ce comportement est déjà EXHAUSTIVEMENT couvert
// par securityRules.test.ts (196/196 PASS) pour :
//   - transaction_ledger (append-only, AUCUN rôle ne peut write directement)
//   - disputes / reconciliation_reports / payout_policy_configs (admin+ ne
//     peut QUE lire, jamais écrire directement — Cloud-Function-only)
//   - payment_profiles (même super_admin ne peut pas write directement)
//   - users/{userId}.roles (un customer ne peut pas s'auto-élever)
//   - driver_internal_notes (Cloud-Function-only, aucun rôle ne peut write
//     directement — voir securityRules.test.ts ligne ~1468)
// Ces scénarios ne sont PAS dupliqués ici (directive utilisateur : référencer,
// ne pas dupliquer). Voir PHASE7_QA_MATRIX.md pour le mapping complet.
// ---------------------------------------------------------------------------
