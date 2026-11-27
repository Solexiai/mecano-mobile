// -----------------------------------------------------------------------------
// Compteur de photos par adresse IP, pour les visiteurs sans compte.
//
// Deux usages envoient une photo à l'IA sans mot de passe :
//   - la page d'estimation (« Pas certain ? Ajoutez une photo ») ;
//   - la demande de livraison d'un visiteur (session invitée, 2026-11-26).
//
// Dans la demande de livraison, le plafond quotidien se compte par compte.
// Or un visiteur obtient une nouvelle session invitée, donc un compteur
// remis à zéro, en vidant son navigateur : seul un plafond par adresse IP le
// borne vraiment (revue du 2026-11-27). Fichier sans dépendance.
// -----------------------------------------------------------------------------

export interface PhotoIpLimits {
  /** Photos permises par fenêtre de `windowMs`. */
  perIpWindow: number;
  windowMs: number;
  perIpPerDay: number;
}

/**
 * Demande de livraison d'un visiteur sans compte : une photo par article,
 * quelques articles, et le droit de reprendre une photo ratée. Plus large que
 * la page d'estimation (une seule photo suffit là-bas), parce que plusieurs
 * personnes peuvent partager une adresse IP (réseau cellulaire, bureau).
 */
export const GUEST_BOOKING_PHOTO_LIMITS: Readonly<PhotoIpLimits> = Object.freeze({
  perIpWindow: 8,
  windowMs: 10 * 60 * 1000,
  perIpPerDay: 24,
});

// A type alias (not an interface) so a stored counter can be passed back in.
export type PhotoIpUsage = {
  day: string;
  count: number;
  windowStartMs: number;
  windowCount: number;
};

/**
 * Le compteur de l'adresse IP après une photo de plus, ou null si un plafond
 * est atteint. Un compteur illisible est traité comme atteint.
 */
export function nextPhotoIpUsage(
  stored: Record<string, unknown> | undefined,
  day: string,
  now: number,
  limits: Readonly<PhotoIpLimits>
): PhotoIpUsage | null {
  const s = stored ?? {};
  const valid = (n: unknown) => n === undefined || (Number.isSafeInteger(n) && (n as number) >= 0);
  if (!valid(s.count) || !valid(s.windowCount) || !valid(s.windowStartMs)) return null;
  const dayCount = s.day === day ? ((s.count as number | undefined) ?? 0) : 0;
  const windowStart = (s.windowStartMs as number | undefined) ?? 0;
  const inWindow = windowStart <= now && now - windowStart < limits.windowMs;
  const windowCount = inWindow ? ((s.windowCount as number | undefined) ?? 0) : 0;
  if (dayCount >= limits.perIpPerDay || windowCount >= limits.perIpWindow) return null;
  return {
    day,
    count: dayCount + 1,
    windowStartMs: inWindow ? windowStart : now,
    windowCount: windowCount + 1,
  };
}
