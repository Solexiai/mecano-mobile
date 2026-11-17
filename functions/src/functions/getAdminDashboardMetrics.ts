import { onCall } from "firebase-functions/v2/https";
import { userKind } from "../lib/userKind";
import { db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";

const ACTIVE_MISSION_STATUSES = [
  "searching_driver",
  "offered",
  "assigned",
  "driver_to_pickup",
  "arrived_at_pickup",
  "picked_up",
  "in_transit",
  "arrived_at_dropoff",
];

const COMPLETED_MISSION_STATUSES = ["completed", "delivered"];
const PENDING_DRIVER_STATUSES = ["pending_review", "documents_required"];

/**
 * Retourne uniquement les compteurs nécessaires au tableau de bord.
 * Les collections financières et personnelles ne sont jamais téléchargées
 * dans le navigateur administrateur.
 */
export const getAdminDashboardMetrics = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const [
    userDocs,
    drivers,
    pendingDrivers,
    pendingReviewDrivers,
    documentsRequiredDrivers,
    unassignedMissions,
    activeMissions,
    completedMissions,
    payments,
    disputes,
  ] = await Promise.all([
    // 2026-11-17 (Daniel) : « 25 clients, c'est une fausse représentation ».
    // On compte les vrais clients (ni chauffeur ni personnel) et le personnel
    // à part ; les comptes effacés ne comptent pas.
    db.collection("users").select("roles", "deleted").get(),
    db.collection("driver_profiles").count().get(),
    db.collection("driver_profiles")
      .where("status", "in", PENDING_DRIVER_STATUSES)
      .count()
      .get(),
    db.collection("driver_profiles").where("status", "==", "pending_review").count().get(),
    db.collection("driver_profiles").where("status", "==", "documents_required").count().get(),
    db.collection("delivery_requests").where("status", "in", ["searching_driver", "offered"]).count().get(),
    db.collection("delivery_requests")
      .where("status", "in", ACTIVE_MISSION_STATUSES)
      .count()
      .get(),
    db.collection("delivery_requests")
      .where("status", "in", COMPLETED_MISSION_STATUSES)
      .count()
      .get(),
    db.collection("payments").count().get(),
    db.collection("disputes").where("status", "in", ["opened", "under_review"]).count().get(),
  ]);

  const openDisputes = disputes.data().count;
  let customers = 0;
  let staff = 0;
  for (const doc of userDocs.docs) {
    const data = doc.data();
    if (data.deleted === true) continue;
    const kind = userKind(Array.isArray(data.roles) ? data.roles : []);
    if (kind === "customer") customers += 1;
    else if (kind === "staff") staff += 1;
  }

  return {
    actionCountsVersion: 1,
    customers,
    staff,
    drivers: drivers.data().count,
    pendingDrivers: pendingDrivers.data().count,
    pendingReviewDrivers: pendingReviewDrivers.data().count,
    documentsRequiredDrivers: documentsRequiredDrivers.data().count,
    unassignedMissions: unassignedMissions.data().count,
    activeMissions: activeMissions.data().count,
    completedMissions: completedMissions.data().count,
    payments: payments.data().count,
    openDisputes,
    generatedAt: new Date().toISOString(),
  };
});
