// SEC-04 (Bloc D, PR 9 — 2026-10-28) — preuves photo (ramassage / livraison).
//
// Avant : `proofOfPickupUrl` / `proofOfDeliveryUrl` acceptaient n'importe
// quelle chaîne (≤ 2048 car.) : un chauffeur pouvait fournir l'image d'un
// autre colis ou un lien externe affiché au client. Maintenant, l'URL doit
// être une URL HTTPS de Cloud Storage pointant DANS le dossier de preuves de
// CETTE mission (`delivery_proofs/{missionId}/…`), là où storage.rules ne
// laisse écrire que le chauffeur assigné.
import { invalidArgument } from "./errors";

const STORAGE_HOSTS = new Set([
  "firebasestorage.googleapis.com",
  "storage.googleapis.com",
  "storage.cloud.google.com",
]);

/** Hôtes supplémentaires acceptés UNIQUEMENT par les tests (jamais défini en prod). */
function testHosts(): Set<string> {
  const raw = process.env.PROOF_URL_TEST_HOSTS;
  return new Set((raw ?? "").split(",").map((h) => h.trim()).filter(Boolean));
}

export function assertProofUrlForMission(url: unknown, missionId: string, field: string): string {
  if (typeof url !== "string" || !url.trim() || url.length > 2048) {
    throw invalidArgument(`${field} est requis : photo obligatoire.`);
  }
  let parsed: URL;
  try {
    parsed = new URL(url.trim());
  } catch {
    throw invalidArgument(`${field} doit être une URL valide.`);
  }
  if (parsed.protocol !== "https:") throw invalidArgument(`${field} doit être une URL HTTPS.`);
  const host = parsed.hostname.toLowerCase();
  if (testHosts().has(host)) return parsed.toString();
  const isStorageHost = STORAGE_HOSTS.has(host) || host.endsWith(".storage.googleapis.com");
  if (!isStorageHost) {
    throw invalidArgument(`${field} doit pointer vers le stockage Movi-K (photo téléversée dans l'application).`);
  }
  // Chemin brut (storage.googleapis.com/bucket/delivery_proofs/id/f.jpg) ou
  // encodé (firebasestorage.googleapis.com/v0/b/bucket/o/delivery_proofs%2Fid%2Ff.jpg).
  const path = decodeURIComponent(parsed.pathname);
  if (!path.includes(`/delivery_proofs/${missionId}/`)) {
    throw invalidArgument(`${field} doit être la photo téléversée pour cette livraison.`);
  }
  return parsed.toString();
}
