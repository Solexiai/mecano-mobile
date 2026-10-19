export interface ActivityMission {
  id: string;
  status?: string;
  customer_id?: string;
  assignment_mode?: string;
}
export interface ActivityRating {
  id: string;
  mission_id?: string;
  rater_id?: string;
  rater_role?: string;
  stars?: unknown;
  comment?: unknown;
}

/** Historical aliases cannot multiply one customer's vote for one mission. */
export function summarizeDriverActivity(
  missions: ActivityMission[], ratings: ActivityRating[]
) {
  const real = missions.filter(m => m.assignment_mode !== "internal_test");
  const eligible = new Map(real.filter(m => m.status === "completed").map(m => [m.id, m]));
  const votes = new Map<string, ActivityRating>();
  for (const rating of ratings) {
    const mission = eligible.get(rating.mission_id ?? "");
    if (!mission || rating.rater_role !== "customer" ||
        rating.rater_id !== mission.customer_id ||
        !Number.isInteger(rating.stars) ||
        (rating.stars as number) < 1 || (rating.stars as number) > 5) continue;
    const previous = votes.get(mission.id);
    if (!previous || rating.id === mission.id + "_customer") votes.set(mission.id, rating);
  }
  const reviews = [...votes.values()].map(r => ({
    stars: r.stars as number,
    comment: typeof r.comment === "string" ? r.comment.slice(0, 2000) : "",
  }));
  return {
    completed: real.filter(m => m.status === "completed").length,
    cancelled: real.filter(m => m.status === "cancelled").length,
    disputed: real.filter(m => m.status === "disputed").length,
    failed: null, // No approved mission-failure classification exists.
    ratingCount: reviews.length,
    rating: reviews.length ? reviews.reduce((n, r) => n + r.stars, 0) / reviews.length : null,
    reviews,
  };
}
