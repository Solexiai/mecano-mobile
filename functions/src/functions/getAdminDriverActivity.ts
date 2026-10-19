import { HttpsError, onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { ActivityMission, ActivityRating, summarizeDriverActivity } from "../lib/driverActivity";

export const getAdminDriverActivity = onCall(async request => {
  requireAnalystOrAbove(requireSignedIn(request));
  const driverId = request.data?.driverId;
  if (typeof driverId !== "string" || !driverId || driverId.length > 128 || driverId.includes("/")) {
    throw new HttpsError("invalid-argument", "A driver identifier is required.");
  }
  const driver = await db.collection("driver_profiles").doc(driverId).get();
  if (!driver.exists || driver.data()?.migrated_to_uid) {
    throw new HttpsError("not-found", "Driver profile unavailable.");
  }
  const snapshot = await db.collection("delivery_requests").where("driver_id", "==", driverId)
    .select("status", "customer_id", "assignment_mode").limit(501).get();
  // Never display truncated totals as complete totals. This read-only endpoint
  // intentionally avoids changing historical financial/mission documents.
  if (snapshot.size > 500) throw new HttpsError("resource-exhausted", "Activity requires paginated reporting.");
  const missions = snapshot.docs.map(d => ({...d.data(), id: d.id})) as ActivityMission[];
  const eligible = missions.filter(m => m.status === "completed" && m.assignment_mode !== "internal_test");
  const ratings: ActivityRating[] = [];
  for (let i = 0; i < eligible.length; i += 30) {
    const batch = await db.collection("ratings")
      .where("mission_id", "in", eligible.slice(i, i + 30).map(m => m.id)).limit(1001).get();
    if (batch.size > 1000) throw new HttpsError("resource-exhausted", "Review history requires paginated reporting.");
    ratings.push(...batch.docs.map(d => ({...d.data(), id: d.id})) as ActivityRating[]);
  }
  return {...summarizeDriverActivity(missions, ratings), generatedAt: new Date().toISOString()};
});
