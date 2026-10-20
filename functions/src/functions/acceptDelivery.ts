import { readSchedulingPolicy, assertNoScheduledCommitments, confirmedSlot, prepareReservation, locationInDriverZone, missionRequestedAt } from '../lib/driverScheduling';
import { createHash } from 'crypto';
import { requireCompatibleVehicle } from "../lib/bookingServer";
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
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { readDriverOfferCompensation } from "../lib/driverOfferCompensation";
import {
  DriverProfileDoc,
  DriverStatuses,
  MissionAssignmentModes,
  MissionStatuses,
  PaymentStatuses,
  OPEN_FOR_ACCEPTANCE_STATUSES,
} from "../lib/types";
import { createAndAuthorizeMissionPayment } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { RuntimeFlagKeys, isRuntimeFlagEnabled, killSwitchRefusal } from "../lib/runtimeFlags";
import { resolveLockedQuote } from "../lib/quoteIntegrity";
import { toMinorUnits } from "../lib/money";
import { supportsVehicleCategory } from "../lib/vehicleCategory";

export interface AcceptDeliveryRequest {
  missionId: string;
  reservation?: unknown;
  acceptanceRequestId?: string;
  vehicleId?: string;
  expectedDriverOfferMinor?: number;
}

function isAuthorizedInternalTestMission(mission: Record<string, unknown>): boolean {
  if (mission.assignment_mode !== MissionAssignmentModes.INTERNAL_TEST) return false;

  // Les missions internes créées avant l'ajout du marqueur serveur n'ont pas
  // ce champ. Elles restent reconnues comme essais internes parce que leur
  // création et leur assignment_mode étaient déjà réservés aux Cloud
  // Functions par les règles Firestore. Toute valeur explicite autre que
  // true — notamment false ou null — reste refusée et suit le parcours
  // financier standard.
  return (
    mission.internal_test_authorized === true ||
    mission.internal_test_authorized === undefined
  );
}

export const acceptDelivery = onCall<AcceptDeliveryRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
  const ctx = requireSignedIn(request);
  const driverId = ctx.uid;
  const { missionId } = request.data;

  if (!missionId || typeof missionId !== "string") {
    throw invalidArgument("missionId est requis.");
  }

  if (request.data.expectedDriverOfferMinor !== undefined &&
      (!Number.isSafeInteger(request.data.expectedDriverOfferMinor) || request.data.expectedDriverOfferMinor < 0)) {
    throw invalidArgument("Rémunération confirmée invalide.");
  }
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const driverRef = db.collection("driver_profiles").doc(driverId);

  // Les missions créées par un superadministrateur en superlogin sont des
  // essais internes. Elles ne doivent jamais appeler Stripe et restent
  // utilisables lorsque les opérations financières réelles sont coupées.
  const missionPreflightSnap = await missionRef.get();
  if (!missionPreflightSnap.exists) {
    throw notFound(`delivery_requests/${missionId} introuvable.`);
  }
  const isInternalTestPreflight = isAuthorizedInternalTestMission(
    missionPreflightSnap.data()!
  );

  if (
    !isInternalTestPreflight &&
    !(await isRuntimeFlagEnabled(RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE))
  ) {
    throw killSwitchRefusal();
  }
  if (
    !isInternalTestPreflight &&
    !(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED))
  ) {
    throw killSwitchRefusal();
  }

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
    const schedulingPolicy = await readSchedulingPolicy(tx);
    const fingerprint = createHash('sha256').update(JSON.stringify({
      reservation:request.data.reservation??null,vehicle:request.data.vehicleId??null,
      expected:request.data.expectedDriverOfferMinor??null,
    })).digest('hex');
    if (schedulingPolicy && (typeof request.data.acceptanceRequestId !== 'string' ||
        !/^[a-zA-Z0-9_-]{16,100}$/.test(request.data.acceptanceRequestId))) {
      throw invalidArgument('Identifiant de confirmation requis.');
    }
    if (typeof request.data.acceptanceRequestId==='string' && mission.driver_id === driverId &&
        mission.acceptance_request_id === request.data.acceptanceRequestId) {
      if(mission.acceptance_fingerprint!==fingerprint)throw failedPrecondition('Cette confirmation a déjà été utilisée avec un autre créneau.');
      if(!['assigned','driver_to_pickup','arrived_at_pickup','picked_up','in_transit','arrived_at_dropoff'].includes(mission.status))throw failedPrecondition('Cette mission n’est plus active.');
      return {replayed:true,paymentStatus:mission.payment_status,paymentId:mission.active_payment_id,missionId,driverOfferAmount:mission.driver_offer_amount,snapshotId:mission.active_financial_snapshot_id,
        customerId:mission.customer_id as string,customerTotal:mission.customer_total,
        applicationFee:0,quoteId:mission.active_quote_id as string,
        internalTest:isAuthorizedInternalTestMission(mission)};
    }
    if(!schedulingPolicy)await assertNoScheduledCommitments(tx,driverId);
    const reservedSlot = schedulingPolicy ? confirmedSlot(request.data.reservation, mission, schedulingPolicy) : null;
    if(!schedulingPolicy && request.data.reservation)throw failedPrecondition('La planification n’est pas encore autorisée.');
    const agendaReservation = reservedSlot ? await prepareReservation(tx,driverId,missionId,reservedSlot) : null;
    const allOffers = schedulingPolicy ? await tx.get(db.collection('delivery_offers').where('mission_id','==',missionId)) : null;
    if(schedulingPolicy && !allOffers!.docs.some(d=>d.data().driver_id===driverId&&d.data().status==='pending'&&d.data().expires_at?.toMillis()>Date.now())){
      throw failedPrecondition('Cette offre est indisponible ou expirée.');
    }
    if(schedulingPolicy){
      if(driverSnap.data()!.online_status!=='online')throw failedPrecondition('Passez en ligne avant d’accepter une offre.');
      const [zones,location] = await Promise.all([tx.get(db.doc('system_config/service_zones')),tx.get(db.doc('driver_locations/'+driverId))]);
      if(!locationInDriverZone(driverSnap.data()!,location.data(),mission.pickup_address,zones.data() as any))throw failedPrecondition('La mission est hors de votre zone admissible.');
    }
    const writeSchedule = () => {
      if(!reservedSlot)return;
      agendaReservation!.write();
      tx.update(missionRef,{scheduling:reservedSlot,duration_confirmation:{driver_id:driverId,confirmed_at:admin.firestore.FieldValue.serverTimestamp(),policy_version:reservedSlot.policy_version},schedule_state:missionRequestedAt(mission)?'reserved':'ready_to_start',
        acceptance_request_id:request.data.acceptanceRequestId,acceptance_fingerprint:fingerprint});
      for(const offer of allOffers!.docs) {
        if(offer.data().status==='pending')tx.update(offer.ref,{status:offer.data().driver_id===driverId?'accepted':'expired',closed_at:admin.firestore.Timestamp.now()});
      }
    };
    const activateTracking = !reservedSlot || !missionRequestedAt(mission);
    if (mission.pricing_snapshot?.pre_assignment &&
        (mission.internal_test_authorized !== true || !isAuthorizedInternalTestMission(mission))) {
      throw failedPrecondition('Ce devis ne permet pas une acceptation commerciale avant validation opérationnelle.');
    }
    const driver = driverSnap.data() as DriverProfileDoc;
    if (request.data.expectedDriverOfferMinor !== undefined) {
      const offers = await tx.get(db.collection('delivery_offers')
        .where('mission_id', '==', missionId).where('driver_id', '==', driverId));
      if (!offers.docs.some(d => d.data().status === 'pending' &&
          typeof d.data().expires_at?.toMillis === 'function' && d.data().expires_at.toMillis() > Date.now())) {
        throw failedPrecondition('Cette offre est indisponible ou expirée.');
      }
    }
    if (mission.booking_snapshot && (typeof request.data.vehicleId !== 'string' || !request.data.vehicleId)) throw failedPrecondition('Confirmez le véhicule utilisé pour cette livraison.');
    const assignedVehicle = await requireCompatibleVehicle(driverId, mission.booking_snapshot, tx, request.data.vehicleId);

    // ---- Vérifications d'éligibilité chauffeur ----
    if (driver.status !== DriverStatuses.APPROVED) {
      throw permissionDenied("Seul un chauffeur approuvé peut accepter une mission.");
    }
    if (!driver.documents_all_valid) {
      throw failedPrecondition("Documents chauffeur invalides ou expirés.");
    }
    if (
      !supportsVehicleCategory(
        driver.accepted_vehicle_categories,
        mission.required_vehicle_category
      )
    ) {
      throw permissionDenied("Catégorie de véhicule non acceptée par ce chauffeur.");
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

    const isInternalTest = isAuthorizedInternalTestMission(mission);
    if (isInternalTest) {
      const now = admin.firestore.Timestamp.now();
      writeSchedule();
      tx.update(missionRef, {
        ...assignedVehicle,
      driver_id: driverId,
        driver_display_name: driver.full_name,
        status: MissionStatuses.ASSIGNED,
        accepted_at: now,
        driver_offer_amount: 0,
        assignment_mode: MissionAssignmentModes.INTERNAL_TEST,
        internal_test_assigned_by: mission.customer_id,
        internal_test_assigned_at: now,
        active_financial_snapshot_id: null,
      });
      if(activateTracking) tx.update(driverRef, { online_status: "on_mission" });
      if(activateTracking) tx.set(
        db.collection("driver_locations").doc(driverId),
        { active_delivery_id: missionId },
        { merge: true }
      );
      const eventRef = missionRef.collection("tracking_events").doc();
      tx.set(eventRef, {
        event_type: "driver_assigned",
        actor_uid: driverId,
        occurred_at: now,
        metadata: { driverId, internal_test: true },
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: driverId,
        actorRole: "driver",
        action: "acceptDeliveryInternalTest",
        sourceFunction: "acceptDelivery",
        targetId: missionId,
        metadata: { internalTest: true },
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
    if (mission.pricing_version !== lockedQuote.pricingVersion) {
      throw failedPrecondition("La version tarifaire de la mission diverge du devis officiel.");
    }
    if (
      toMinorUnits(mission.customer_total) !== lockedQuote.customerTotalMinor ||
      (mission.customer_total_minor !== undefined &&
        mission.customer_total_minor !== lockedQuote.customerTotalMinor)
    ) {
      throw failedPrecondition("Le total de la mission diverge du devis officiel.");
    }
    if (
      lockedQuote.integrityHash &&
      mission.quote_integrity_hash !== lockedQuote.integrityHash
    ) {
      throw failedPrecondition("L'empreinte du devis copiée dans la mission est invalide.");
    }

    // La grille est relue uniquement pour les règles de commission chauffeur.
    // Le prix client, les taxes, promotions, manutention, arrêts et majorations
    // proviennent intégralement du devis figé ci-dessus et ne sont jamais recalculés.
    const { pricingConfig, pricingResult, now, resolved, compensation } =
      await readDriverOfferCompensation(tx, driverId, lockedQuote);
    const taxSnapshot =
      lockedQuote.pricingSnapshot?.tax_snapshot ?? quote.tax_snapshot ?? null;
    if (request.data.expectedDriverOfferMinor !== undefined &&
        request.data.expectedDriverOfferMinor !== toMinorUnits(compensation.driverOfferAmount)) {
      throw failedPrecondition('La rémunération a changé. Consultez de nouveau les conditions avant de confirmer.');
    }

    // ---- Écriture atomique : mission + driver_profile + snapshot pending ----
    writeSchedule();
    tx.update(missionRef, {
      ...assignedVehicle,
      driver_id: driverId,
      driver_display_name: driver.full_name,
      status: MissionStatuses.ASSIGNED,
      accepted_at: now,
      driver_offer_amount: compensation.driverOfferAmount,
      // Défense en profondeur : une acceptation normale reste toujours
      // financière, même si un ancien document a été altéré avant que les
      // règles Firestore protègent ce champ serveur.
      assignment_mode: MissionAssignmentModes.STANDARD,
      internal_test_assigned_by: null,
      internal_test_assigned_at: null,
    });

    if(activateTracking) tx.update(driverRef, { online_status: "on_mission" });

    // Active le tracking GPS temps réel pour cette mission (Phase 5) :
    // recordTrackingPoint() lit ce champ pour savoir sur quelle mission
    // rattacher l'historique, et firestore.rules l'utilise pour autoriser
    // le client à lire la position du chauffeur pendant SA mission active.
    if(activateTracking) tx.set(
      db.collection("driver_locations").doc(driverId),
      { active_delivery_id: missionId },
      { merge: true }
    );

    const snapshotRef = db.collection("financial_snapshots").doc();
    tx.set(snapshotRef, {
      snapshot_id: snapshotRef.id,
      mission_id: missionId,
      customer_id: mission.customer_id,
      ...assignedVehicle,
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
    tx.set(eventRef, { event_type: "driver_assigned", actor_uid: driverId, occurred_at: now, metadata: { driverId } });

    writeAuditLogInTransaction(tx, {
      actorUserId: driverId,
      actorRole: "driver",
      action: "acceptDelivery",
      sourceFunction: "acceptDelivery",
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
    };
  }

  if('replayed' in result && result.replayed){
    const success=[PaymentStatuses.AUTHORIZED,PaymentStatuses.CAPTURED].includes(result.paymentStatus);
    return {success,pending:!success,errorCode:success?null:'acceptance_pending',missionId:result.missionId,
      driverOfferAmount:result.driverOfferAmount,snapshotId:result.snapshotId,paymentId:result.paymentId??null};
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
    if (paymentOutcome.status === PaymentStatuses.CANCELLED) {
      throw failedPrecondition(
        "Mission annulée pendant l'autorisation ; autorisation de paiement libérée."
      );
    }
    if (paymentOutcome.status === PaymentStatuses.AUTHORIZED) {
      throw failedPrecondition(
        "Mission annulée ; vérification de la libération du paiement nécessaire."
      );
    }
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
  };
  }
);
