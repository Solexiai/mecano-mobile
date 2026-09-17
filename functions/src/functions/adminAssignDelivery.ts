// -----------------------------------------------------------------------------
// acceptDelivery — Cloud Function callable (driver). 🔒 CŒUR DE L'ATOMICITÉ.
//
// EXIGENCE EXPLICITE DU CAHIER DES CHARGES :
// « acceptDelivery doit utiliser une transaction Firestore. Elle doit
//   relire la mission dans la transaction et vérifier qu'elle est toujours
//   disponible avant de l'assigner. Le premier commit valide gagne. Aucune
//   logique frontend ne doit déterminer le gagnant. »
//
// GARANTIE D'ATOMICITÉ FIRESTORE :
// `db.runTransaction()` relit `missionRef` via `tx.get()` DANS la
// transaction. Si deux chauffeurs appellent `acceptDelivery` en même temps
// pour la même mission, Firestore détecte au commit que le document lu a
// changé entre temps pour l'un des deux appels et RÉESSAIE automatiquement
// cette transaction (jusqu'à 5 tentatives par défaut du SDK Admin). À la
// relecture suivante, `status` ne sera plus `searching_driver`/`offered`
// (l'autre transaction aura déjà gagné et committé `assigned`), et cette
// fonction lèvera alors `failed-precondition` pour le perdant. Le frontend
// ne fait qu'appeler cette fonction et afficher le résultat — il ne décide
// jamais qui gagne.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn, requireSuperAdmin } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  calculateDriverCompensation,
  resolveCommission,
} from "../lib/pricingEngine";
import {
  CommissionConfigDoc,
  DriverProfileDoc,
  DriverStatuses,
  FoundingDriverProgramDoc,
  FoundingDriverQualificationDoc,
  FoundingDriverStatuses,
  MissionAssignmentModes,
  MissionStatuses,
  OPEN_FOR_ACCEPTANCE_STATUSES,
  PricingVersionDoc,
} from "../lib/types";
import { createAndAuthorizeMissionPayment } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { RuntimeFlagKeys, isRuntimeFlagEnabled, killSwitchRefusal } from "../lib/runtimeFlags";
import { resolveLockedQuote } from "../lib/quoteIntegrity";
import { toMinorUnits } from "../lib/money";

export interface AdminAssignDeliveryRequest {
  missionId: string;
  driverId: string;
  assignmentMode?: "standard" | "internal_test";
}

export const adminAssignDelivery = onCall<AdminAssignDeliveryRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const actorId = ctx.uid;
  const { missionId, driverId } = request.data;
  const assignmentMode = request.data.assignmentMode ?? MissionAssignmentModes.STANDARD;
  if (!Object.values(MissionAssignmentModes).includes(assignmentMode)) {
    throw invalidArgument("assignmentMode invalide.");
  }
  const isInternalTest = assignmentMode === MissionAssignmentModes.INTERNAL_TEST;
  if (isInternalTest) {
    // Seul un super-administrateur peut contourner les interrupteurs de
    // production. Ce chemin n’effectue aucune opération financière.
    requireSuperAdmin(ctx);
  }

  // 🔒 Phase 7, Bloc X (X-7) — kill switch. OFF => aucune NOUVELLE
  // attribution de mission n'est possible. Les missions DÉJÀ assignées
  // (statut != OPEN_FOR_ACCEPTANCE_STATUSES) continuent leur cycle de vie
  // normalement (aucun autre point du code ne consulte ce flag). Vérifié
  // AVANT toute lecture Firestore pour qu'un client modifié ne puisse
  // jamais contourner ce contrôle serveur-autoritaire.
  if (!isInternalTest && !(await isRuntimeFlagEnabled(RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE))) {
    throw killSwitchRefusal();
  }

  // 🔒 Phase 7, Bloc X (X-8) — GAP P1 CORRIGÉ (voir docs/PHASE7_BUG_REPORT.md,
  // BUG-X-01). acceptDelivery() déclenche TOUJOURS une autorisation de
  // paiement immédiatement après avoir assigné la mission (voir
  // createAndAuthorizeMissionPayment ci-dessous) — l'acceptation et le
  // paiement forment ici une seule opération métier indissociable. Vérifier
  // `payments_enabled` ICI, AVANT la transaction d'assignation, garantit
  // qu'un OFF :
  //   - ne touche à AUCUN fonds (aucun appel provider, aucun payments/{id})
  //   - ne modifie AUCUN état de mission (aucune transaction n'a encore
  //     commité — la mission reste `searching_driver`/`offered`, disponible
  //     pour une reprise propre par CE chauffeur ou un autre dès que le
  //     flag repasse à `true`)
  //   - retourne l'erreur structurée standard (killSwitchRefusal())
  // Ancien comportement (CORRIGÉ) : le contrôle était fait APRÈS la
  // transaction d'assignation, à l'intérieur de createAndAuthorizeMissionPayment
  // — la mission était donc déjà assignée puis basculée en
  // MissionStatuses.PAYMENT_FAILED, un statut documenté comme TERMINAL/SANS
  // REPRISE ("le client doit créer une nouvelle demande" — voir types.ts).
  // Un kill switch représente une indisponibilité TEMPORAIRE du service, pas
  // un échec définitif de paiement : ce statut terminal était donc une
  // sémantique incorrecte pour ce cas précis (voir X-8, section "IMPORTANT —
  // TESTER LA SÉMANTIQUE de failMissionPayment()").
  if (!isInternalTest && !(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED))) {
    throw killSwitchRefusal();
  }

  if (!missionId || typeof missionId !== "string") {
    throw invalidArgument("missionId est requis.");
  }
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }

  const missionRef = db.collection("delivery_requests").doc(missionId);
  const driverRef = db.collection("driver_profiles").doc(driverId);

  const result = await db.runTransaction(async (tx) => {
    // ---- RELECTURE DANS LA TRANSACTION (garantie d'atomicité) ----
    const [missionSnap, driverSnap] = await Promise.all([tx.get(missionRef), tx.get(driverRef)]);

    if (!missionSnap.exists) {
      throw notFound(`delivery_requests/${missionId} introuvable.`);
    }
    if (!driverSnap.exists) {
      throw notFound(`driver_profiles/${driverId} introuvable.`);
    }

    const mission = missionSnap.data()!;
    const driver = driverSnap.data() as DriverProfileDoc;

    // ---- Vérifications d'éligibilité chauffeur ----
    if (driver.status !== DriverStatuses.APPROVED) {
      throw permissionDenied("Seul un chauffeur approuvé peut accepter une mission.");
    }
    if (!driver.documents_all_valid) {
      throw failedPrecondition("Documents chauffeur invalides ou expirés.");
    }
    if (!driver.accepted_vehicle_categories.includes(mission.required_vehicle_category)) {
      throw permissionDenied("Catégorie de véhicule non acceptée par ce chauffeur.");
    }
    if (driver.online_status === "on_mission") {
      throw failedPrecondition("Ce chauffeur est déjà affecté à une mission.");
    }

    // ---- LA vérification décisive : la mission est-elle encore ouverte ? ----
    // C'est précisément cette lecture, faite DANS la transaction, qui
    // garantit qu'un seul appel concurrent peut committer avec succès.
    if (!OPEN_FOR_ACCEPTANCE_STATUSES.includes(mission.status)) {
      throw failedPrecondition(
        `Mission déjà ${mission.status} — un autre chauffeur a probablement déjà accepté.`
      );
    }
    if (mission.driver_id) {
      throw failedPrecondition("Mission déjà assignée à un autre chauffeur.");
    }

    if (
      isInternalTest &&
      (mission.active_payment_id || mission.active_financial_snapshot_id)
    ) {
      throw failedPrecondition(
        "Une mission déjà liée à un paiement ne peut pas être convertie en test interne."
      );
    }

    if (isInternalTest) {
      const now = admin.firestore.Timestamp.now();

      // Le mode interne assigne réellement le chauffeur pour permettre le
      // parcours terrain complet, mais ne crée aucun contrat financier.
      tx.update(missionRef, {
        driver_id: driverId,
        driver_display_name: driver.full_name,
        status: MissionStatuses.ASSIGNED,
        accepted_at: now,
        driver_offer_amount: 0,
        assignment_mode: MissionAssignmentModes.INTERNAL_TEST,
        internal_test_assigned_by: actorId,
        internal_test_assigned_at: now,
        active_financial_snapshot_id: null,
        active_payment_id: null,
      });
      tx.update(driverRef, { online_status: "on_mission" });
      tx.set(
        db.collection("driver_locations").doc(driverId),
        { active_delivery_id: missionId },
        { merge: true }
      );

      const eventRef = missionRef.collection("tracking_events").doc();
      tx.set(eventRef, {
        event_type: "driver_assigned",
        actor_uid: actorId,
        occurred_at: now,
        metadata: { driverId, assignmentSource: "admin_internal_test" },
      });

      writeAuditLogInTransaction(tx, {
        actorUserId: actorId,
        actorRole: ctx.role ?? "super_admin",
        action: "adminAssignDeliveryInternalTest",
        sourceFunction: "adminAssignDelivery",
        targetId: missionId,
        metadata: { driverId, assignmentMode: MissionAssignmentModes.INTERNAL_TEST },
      });

      return {
        missionId,
        driverOfferAmount: 0,
        snapshotId: null,
        customerId: mission.customer_id as string,
        customerTotal: 0,
        applicationFee: 0,
        internalTest: true,
      };
    }

    // ---- Devis officiel : source unique de vérité financière ----
    if (typeof mission.active_quote_id !== "string" || !mission.active_quote_id) {
      throw failedPrecondition("Cette mission standard n'est liée à aucun devis officiel.");
    }
    const quoteRef = db.collection("delivery_quotes").doc(mission.active_quote_id);
    const quoteSnap = await tx.get(quoteRef);
    if (!quoteSnap.exists) {
      throw failedPrecondition(`delivery_quotes/${mission.active_quote_id} introuvable.`);
    }
    const quote = quoteSnap.data()!;
    if (
      quote.customer_id !== mission.customer_id ||
      quote.mission_id !== missionId ||
      quote.is_consumed !== true
    ) {
      throw failedPrecondition("Le devis officiel n'est pas lié de façon valide à cette mission.");
    }
    if (quote.status === "cancelled" || quote.cancelled_at) {
      throw failedPrecondition("Le devis lié à cette mission a été annulé.");
    }
    const lockedQuote = resolveLockedQuote(mission.active_quote_id, quote);
    if (
      mission.pricing_version !== lockedQuote.pricingVersion ||
      toMinorUnits(mission.customer_total) !== lockedQuote.customerTotalMinor ||
      (mission.customer_total_minor !== undefined &&
        mission.customer_total_minor !== lockedQuote.customerTotalMinor)
    ) {
      throw failedPrecondition("Les données tarifaires de la mission divergent du devis officiel.");
    }
    if (lockedQuote.integrityHash && mission.quote_integrity_hash !== lockedQuote.integrityHash) {
      throw failedPrecondition("L'empreinte du devis copiée dans la mission est invalide.");
    }

    const versionSnap = await tx.get(
      db.collection("pricing_versions").doc(lockedQuote.pricingVersion)
    );
    if (!versionSnap.exists) {
      throw failedPrecondition(`pricing_versions/${mission.pricing_version} introuvable.`);
    }
    const pricingConfig = versionSnap.data() as PricingVersionDoc;
    const pricingResult = lockedQuote.pricingResult;
    const taxSnapshot = lockedQuote.pricingSnapshot?.tax_snapshot ?? quote.tax_snapshot ?? null;

    // ---- Résolution de commission : Founding Driver > promo > standard ----
    // 🔒 BLOC O — CORRECTIF : on ne suppose JAMAIS un `programId` fixe
    // ("default" était une hypothèse ad-hoc jamais bootstrapée ailleurs dans
    // le projet — voir qualifyFoundingDriver.ts, qui accepte n'importe quel
    // `programId` fourni par l'admin). On cherche la qualification RÉELLE du
    // chauffeur via une requête collection-group sur `qualifications`
    // (indexée par `driver_id`, voir firestore.indexes.json), puis on charge
    // le VRAI programme référencé par `qualification.program_id`. L'absence
    // de qualification est un cas NORMAL (grande majorité des chauffeurs),
    // jamais une erreur.
    const qualQuerySnap = await tx.get(
      db.collectionGroup("qualifications").where("driver_id", "==", driverId).limit(1)
    );
    const promoSnap = await tx.get(
      db.collection("driver_promotions").where("driver_id", "==", driverId).limit(1)
    );

    let foundingQualificationForResolver: { status: string; promotionalPeriodEndsAtMillis: number } | null =
      null;
    let foundingProgramForResolver: { promotionalCommissionRate: number; preferredCommissionRate: number } | null =
      null;

    if (!qualQuerySnap.empty) {
      const qual = qualQuerySnap.docs[0].data() as FoundingDriverQualificationDoc;
      foundingQualificationForResolver = {
        status: qual.status,
        promotionalPeriodEndsAtMillis: qual.promotional_period_ends_at.toMillis(),
      };

      if (qual.status === FoundingDriverStatuses.QUALIFIED) {
        // 🔒 Une qualification 'qualified' DOIT référencer un programme réel
        // et cohérent — jamais un taux Founding inventé localement. Toute
        // incohérence (program_id manquant, programme introuvable, programme
        // désactivé, taux manquants/invalides) est une CORRUPTION DE
        // CONFIGURATION : on refuse explicitement le calcul (failed-precondition)
        // plutôt que de retomber silencieusement sur le taux standard (perte
        // injustifiée pour un chauffeur légitimement Founding) ou d'inventer
        // un taux local (remise commerciale silencieuse non auditée).
        if (!qual.program_id) {
          throw failedPrecondition(
            `Qualification Founding Driver de ${driverId} incohérente : program_id manquant.`
          );
        }
        const programSnap = await tx.get(
          db.collection("founding_driver_programs").doc(qual.program_id)
        );
        if (!programSnap.exists) {
          throw failedPrecondition(
            `founding_driver_programs/${qual.program_id} introuvable (référencé par la qualification de ${driverId}).`
          );
        }
        const program = programSnap.data() as FoundingDriverProgramDoc;
        if (program.is_active === false) {
          throw failedPrecondition(
            `founding_driver_programs/${qual.program_id} est désactivé — configuration Founding Driver incohérente pour ${driverId}.`
          );
        }
        if (
          typeof program.promotional_commission_rate !== "number" ||
          typeof program.preferred_commission_rate !== "number"
        ) {
          throw failedPrecondition(
            `founding_driver_programs/${qual.program_id} : taux de commission manquants ou invalides.`
          );
        }
        foundingProgramForResolver = {
          promotionalCommissionRate: program.promotional_commission_rate,
          preferredCommissionRate: program.preferred_commission_rate,
        };
      }
    }

    const now = admin.firestore.Timestamp.now();
    const resolved = resolveCommission({
      nowMillis: now.toMillis(),
      foundingQualification: foundingQualificationForResolver,
      foundingProgram: foundingProgramForResolver,
      activePromotion:
        !promoSnap.empty && promoSnap.docs[0].data().is_active
          ? {
              promotionalCommissionRate: promoSnap.docs[0].data().promotional_commission_rate,
              startsAtMillis: promoSnap.docs[0].data().starts_at.toMillis(),
              endsAtMillis: promoSnap.docs[0].data().ends_at.toMillis(),
              isActive: promoSnap.docs[0].data().is_active,
            }
          : null,
      standardRate: (pricingConfig.commission as CommissionConfigDoc).standard_commission_rate,
    });

    const compensation = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolved,
      commissionConfig: pricingConfig.commission,
    });

    // ---- Écriture atomique : mission + driver_profile + snapshot pending ----
    tx.update(missionRef, {
      driver_id: driverId,
      driver_display_name: driver.full_name,
      status: MissionStatuses.ASSIGNED,
      accepted_at: now,
      driver_offer_amount: compensation.driverOfferAmount,
      assignment_mode: MissionAssignmentModes.STANDARD,
    });

    tx.update(driverRef, { online_status: "on_mission" });

    // Active le tracking GPS temps réel pour cette mission (Phase 5) :
    // recordTrackingPoint() lit ce champ pour savoir sur quelle mission
    // rattacher l'historique, et firestore.rules l'utilise pour autoriser
    // le client à lire la position du chauffeur pendant SA mission active.
    tx.set(
      db.collection("driver_locations").doc(driverId),
      { active_delivery_id: missionId },
      { merge: true }
    );

    const snapshotRef = db.collection("financial_snapshots").doc();
    tx.set(snapshotRef, {
      snapshot_id: snapshotRef.id,
      mission_id: missionId,
      customer_id: mission.customer_id,
      driver_id: driverId,
      pricing_version: mission.pricing_version,
      quote_id: mission.active_quote_id,
      quote_integrity_hash: lockedQuote.integrityHash,
      quote_schema_version: lockedQuote.pricingSnapshot?.schema_version ?? 0,
      pricing_snapshot: lockedQuote.pricingSnapshot,
      quote_breakdown: pricingResult,
      mission_base_value: pricingResult.missionBaseValue,
      driver_gross_earnings: compensation.driverGrossEarnings,
      driver_offer_amount: compensation.driverOfferAmount,
      commission_rate: resolved.rate,
      commission_program: resolved.program,
      minimum_platform_commission: pricingConfig.commission.minimum_platform_commission,
      maximum_effective_commission_rate:
        pricingConfig.commission.maximum_effective_commission_rate,
      platform_commission_amount: compensation.platformCommissionAmount,
      customer_service_fee: pricingResult.customerServiceFee,
      customer_fees:
        pricingResult.handlingFeesTotal + pricingResult.waitingFee + pricingResult.additionalStopsFee,
      customer_discount: pricingResult.customerDiscountAmount,
      customer_tax: pricingResult.taxAmount,
      // 🔒 BLOC E — snapshot fiscal figé au moment où la mission devient
      // contractuelle (point 15). `null` tant qu'aucune TaxConfigDoc active
      // n'existe pour la juridiction (comportement de repli explicite, pas
      // une pseudo-règle silencieuse — voir taxEngine.ts). Une fois écrit,
      // ce champ n'est JAMAIS modifié même si tax_configs change ensuite.
      tax_snapshot: taxSnapshot,
      driver_bonus: 0,
      tip_amount: 0,
      driver_net_mission_earnings: compensation.driverNetMissionEarnings,
      driver_total_payout: compensation.driverNetMissionEarnings,
      payment_processing_cost: 0,
      insurance_cost: 0,
      customer_total: pricingResult.customerTotal,
      customer_total_minor: lockedQuote.customerTotalMinor,
      platform_gross_revenue: compensation.platformCommissionAmount + pricingResult.customerServiceFee,
      contribution_margin: compensation.platformCommissionAmount + pricingResult.customerServiceFee,
      created_at: now,
      confirmed_at: null,
      status: "pending", // confirmé par completeDelivery()
    });

    tx.update(missionRef, { active_financial_snapshot_id: snapshotRef.id });

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, { event_type: "driver_assigned", actor_uid: actorId, occurred_at: now, metadata: { driverId, assignmentSource: "admin_manual" } });

    writeAuditLogInTransaction(tx, {
      actorUserId: actorId,
      actorRole: ctx.role ?? "admin",
      action: "adminAssignDelivery",
      sourceFunction: "adminAssignDelivery",
      targetId: missionId,
      metadata: { snapshotId: snapshotRef.id },
    });

    return {
      missionId,
      driverOfferAmount: compensation.driverOfferAmount,
      snapshotId: snapshotRef.id,
      customerId: mission.customer_id as string,
      customerTotal: pricingResult.customerTotal,
      customerTotalMinor: lockedQuote.customerTotalMinor,
      applicationFee: compensation.platformCommissionAmount + pricingResult.customerServiceFee,
      quoteId: mission.active_quote_id as string,
      internalTest: false,
    };
  });

  if (result.internalTest) {
    return {
      success: true,
      missionId: result.missionId,
      driverOfferAmount: 0,
      snapshotId: null,
      paymentId: null,
      internalTest: true,
      paymentSkipped: true,
    };
  }

  // ---- PHASE 6, point 1/5 : sécurisation RÉELLE du paiement -----------------
  // Exécuté APRÈS le commit de la transaction ci-dessus (jamais À L'INTÉRIEUR
  // — voir paymentOrchestration.ts pour la justification : un appel Stripe
  // dans une transaction Firestore pourrait être ré-exécuté par un retry de
  // contention). Un échec d'autorisation bascule la mission en
  // `payment_failed` et la désassigne (compensation gérée par
  // createAndAuthorizeMissionPayment lui-même) — le chauffeur reçoit alors
  // une erreur explicite plutôt qu'une mission fantôme non payée.
  const paymentOutcome = await createAndAuthorizeMissionPayment({
    missionId: result.missionId,
    customerId: result.customerId,
    driverId,
    quoteId: result.quoteId!,
    financialSnapshotId: result.snapshotId!,
  });

  if (!paymentOutcome.success) {
    throw failedPrecondition(
      `Autorisation de paiement refusée (${paymentOutcome.status}): ${
        paymentOutcome.failureMessage ?? "raison inconnue"
      }. La mission est passée en statut 'payment_failed' et n'est plus assignée ; le client doit corriger son moyen de paiement puis soumettre une nouvelle demande.`
    );
  }

  return {
    success: true,
    missionId: result.missionId,
    driverOfferAmount: result.driverOfferAmount,
    snapshotId: result.snapshotId,
    paymentId: paymentOutcome.paymentId,
    internalTest: false,
    paymentSkipped: false,
  };
  }
);
