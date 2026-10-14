// GAP-S-04: the two admin-approved suspension modes for an assigned driver.
// Legacy suspended profiles without an explicit mode fail closed as urgent.
import type { Transaction } from "firebase-admin/firestore";
import { db } from "./admin";
import { permissionDenied } from "./errors";
import { DriverStatuses } from "./types";

export const SuspensionModes = {
  ORDINARY: "ordinary",
  URGENT: "urgent",
} as const;
export type SuspensionMode = (typeof SuspensionModes)[keyof typeof SuspensionModes];

export function isUrgentSuspension(profile: Record<string, unknown>): boolean {
  return profile.status === DriverStatuses.SUSPENDED &&
    profile.suspension_mode !== SuspensionModes.ORDINARY;
}

export async function requireMissionProgressPermission(
  tx: Transaction,
  driverId: string
): Promise<{ suspendedOrdinary: boolean }> {
  const snapshot = await tx.get(db.collection("driver_profiles").doc(driverId));
  if (!snapshot.exists) {
    throw permissionDenied("Profil chauffeur introuvable : progression de mission refusée.");
  }
  const profile = snapshot.data()!;
  if (profile.status === DriverStatuses.APPROVED) {
    return { suspendedOrdinary: false };
  }
  if (profile.status === DriverStatuses.SUSPENDED &&
      profile.suspension_mode === SuspensionModes.ORDINARY) {
    // Caller must first validate assignment + active mission status.
    return { suspendedOrdinary: true };
  }
  throw permissionDenied("Suspension urgente ou chauffeur non admissible : contactez l'administration.");
}
