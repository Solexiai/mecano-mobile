// -----------------------------------------------------------------------------
// Vérification des rôles à partir des Firebase Auth Custom Claims UNIQUEMENT.
//
// 🔒 Ne JAMAIS lire `users/{uid}.roles` (Firestore) pour autoriser une
// action serveur — ce champ n'est qu'un miroir d'affichage. La seule source
// de vérité pour l'autorisation est `request.auth.token.role` /
// `request.auth.token.roles`, injectés par `setUserRole()` via
// `admin.auth().setCustomUserClaims()`.
// -----------------------------------------------------------------------------

import type { CallableRequest } from "firebase-functions/v2/https";
import { permissionDenied, unauthenticated } from "./errors";
import { PlatformRole, PlatformRoles } from "./types";

export interface AuthContext {
  uid: string;
  role: PlatformRole | undefined;
  roles: PlatformRole[];
  email?: string;
  /**
   * 🔒 SEC-02 — compte de test interne, attribué UNIQUEMENT par un
   * super_admin via `setUserRole({ internalTester: true })` (custom claim
   * `internal_tester`). Jamais déduit d'un courriel.
   */
  internalTester: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function requireSignedIn(request: CallableRequest<any>): AuthContext {
  if (!request.auth) {
    throw unauthenticated();
  }
  const token = request.auth.token as Record<string, unknown>;
  const role = token.role as PlatformRole | undefined;
  const roles = (token.roles as PlatformRole[] | undefined) ?? (role ? [role] : []);
  return {
    uid: request.auth.uid,
    roles,
    role,
    email: typeof token.email === "string" ? token.email.toLowerCase() : undefined,
    internalTester: token[INTERNAL_TESTER_CLAIM] === true,
  };
}

export function requireAnyRole(ctx: AuthContext, allowed: PlatformRole[]): void {
  const ok = ctx.roles.some((r) => allowed.includes(r));
  if (!ok) {
    throw permissionDenied(
      `Rôle insuffisant. Requis: ${allowed.join(" | ")}. Actuel: ${ctx.roles.join(",") || "aucun"}.`
    );
  }
}

const ANALYST_OR_ABOVE: PlatformRole[] = [
  PlatformRoles.ANALYST,
  PlatformRoles.ADMIN,
  PlatformRoles.SUPER_ADMIN,
];
const ADMIN_OR_ABOVE: PlatformRole[] = [PlatformRoles.ADMIN, PlatformRoles.SUPER_ADMIN];

export function isAnalystOrAbove(ctx: AuthContext): boolean {
  return ctx.roles.some((r) => ANALYST_OR_ABOVE.includes(r));
}

export function isAdminOrAbove(ctx: AuthContext): boolean {
  return ctx.roles.some((r) => ADMIN_OR_ABOVE.includes(r));
}

export function isSuperAdmin(ctx: AuthContext): boolean {
  return ctx.roles.includes(PlatformRoles.SUPER_ADMIN);
}

/**
 * 🔒 SEC-02 (rapport pré-lancement 2026-10-27) — l'ancien privilège par
 * COURRIEL EN DUR (`demo.client.160926@movi-k.com`) est retiré : si ce
 * compte n'existait pas en production, n'importe qui pouvait le créer par
 * l'inscription ouverte et obtenir des missions sans paiement, hors
 * interrupteurs et hors pause. Le compte de test interne est désormais un
 * custom claim Firebase Auth (`internal_tester: true`) que seul un
 * super_admin peut poser via `setUserRole`. Un super_admin connecté reste
 * lui-même un testeur interne (comportement inchangé).
 */
export const INTERNAL_TESTER_CLAIM = "internal_tester";

export function isInternalTester(ctx: AuthContext): boolean {
  return ctx.internalTester === true || isSuperAdmin(ctx);
}

export function requireAnalystOrAbove(ctx: AuthContext): void {
  if (!isAnalystOrAbove(ctx)) {
    throw permissionDenied("Rôle analyst/admin/super_admin requis.");
  }
}

export function requireAdminOrAbove(ctx: AuthContext): void {
  if (!isAdminOrAbove(ctx)) {
    throw permissionDenied("Rôle admin/super_admin requis.");
  }
}

export function requireSuperAdmin(ctx: AuthContext): void {
  if (!isSuperAdmin(ctx)) {
    throw permissionDenied("Rôle super_admin requis.");
  }
}
