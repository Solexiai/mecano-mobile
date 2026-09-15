import { onCall } from "firebase-functions/v2/https";
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
    customers,
    drivers,
    pendingDrivers,
    activeMissions,
    completedMissions,
    payments,
    disputes,
  ] = await Promise.all([
    db.collection("users").where("roles", "array-contains", "customer").count().get(),
    db.collection("driver_profiles").count().get(),
    db.collection("driver_profiles")
      .where("status", "in", PENDING_DRIVER_STATUSES)
      .count()
      .get(),
    db.collection("delivery_requests")
      .where("status", "in", ACTIVE_MISSION_STATUSES)
      .count()
      .get(),
    db.collection("delivery_requests")
      .where("status", "in", COMPLETED_MISSION_STATUSES)
      .count()
      .get(),
    db.collection("payments").count().get(),
    db.collection("disputes").get(),
  ]);

  const openDisputes = disputes.docs.filter(
    (document) => document.data().status !== "resolved"
  ).length;

  return {
    customers: customers.data().count,
    drivers: drivers.data().count,
    pendingDrivers: pendingDrivers.data().count,
    activeMissions: activeMissions.data().count,
    completedMissions: completedMissions.data().count,
    payments: payments.data().count,
    openDisputes,
    generatedAt: new Date().toISOString(),
  };
});
