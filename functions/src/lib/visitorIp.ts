// Fichier sans dépendance : il sert autant aux fonctions publiques qu'à
// l'analyse de photo de la demande de livraison.
import type { CallableRequest } from "firebase-functions/v2/https";

/**
 * Adresse IP du visiteur. Derrière Google, la dernière valeur de
 * `x-forwarded-for` est celle que Google a vue ; les précédentes sont
 * écrites par le visiteur et ne comptent pas.
 */
export function visitorIp(request: Pick<CallableRequest<unknown>, "rawRequest">): string {
  const raw = request.rawRequest as unknown as { headers?: Record<string, unknown>; ip?: unknown } | undefined;
  const header = raw?.headers?.["x-forwarded-for"];
  const forwarded = (Array.isArray(header) ? header.join(",") : typeof header === "string" ? header : "")
    .split(",").map((part) => part.trim()).filter(Boolean);
  const ip = forwarded.length ? forwarded[forwarded.length - 1] : typeof raw?.ip === "string" ? raw.ip : "";
  return ip && ip.length <= 64 ? ip : "unknown";
}
