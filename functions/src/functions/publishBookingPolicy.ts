// -----------------------------------------------------------------------------
// publishBookingPolicy — PAY-12 (2026-10-27). Jusqu'ici, le seul chemin
// d'écriture de system_config/booking_policy était la version D'ESSAI figée
// dans le code (adminPilotSetup "publishTrialTerms"). Les conditions finales
// (relues par un juriste) n'avaient aucun chemin de publication : ce
// callable l'ajoute, avec la même validation que le serveur applique à
// chaque réservation (parseBookingPolicy : approuvée, versionnée, trois
// documents complets, URLs https, empreinte de contenu).
//
//   - "get"     : la politique publiée, texte complet (pour l'éditeur admin),
//                 ou la version d'essai comme point de départ s'il n'y a rien.
//   - "preview" : valide un projet sans rien écrire ; renvoie l'empreinte.
//   - "publish" : écrit la politique (jamais marquée d'essai). Une nouvelle
//                 version est obligatoire dès que le contenu change : chaque
//                 réservation copie le texte accepté et sa version, et le
//                 consentement est invalidé par l'empreinte si le texte
//                 change sans changement de version (bookingContract.ts).
//
// Réservé aux admins (comme adminPilotSetup) ; chaque publication est
// journalisée (audit_logs : booking_policy_published, version, empreinte,
// version précédente). Les réglages publics (runtime_flags) ne bougent pas.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { BookingPolicy, parseBookingPolicy } from "../lib/bookingContract";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import { RUNTIME_FLAGS_COLLECTION } from "../lib/runtimeFlags";
import { trialBookingPolicy } from "../config/trialBookingPolicy";

const MAX_PAYLOAD_BYTES = 600000;
const VERSION_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;

/** Ce que l'admin voit et édite : la politique sans les champs techniques. */
function editableView(raw: Record<string, unknown> | undefined): Record<string, unknown> | null {
  if (!raw) return null;
  const parsed = parseBookingPolicy(raw);
  if (!parsed) return null;
  const { contract_hash: _hash, ...rest } = parsed;
  void _hash;
  return {
    ...rest,
    trial: raw.trial === true,
    published_at: raw.published_at ?? null,
    published_by_user_id: raw.published_by_user_id ?? null,
    contract_hash: parsed.contract_hash,
  };
}

function parseDraft(value: unknown): BookingPolicy {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw invalidArgument("Politique invalide.");
  const raw = value as Record<string, unknown>;
  if (Buffer.byteLength(JSON.stringify(raw), "utf8") > MAX_PAYLOAD_BYTES) {
    throw invalidArgument("Politique trop volumineuse.");
  }
  if (typeof raw.version !== "string" || !VERSION_PATTERN.test(raw.version)) {
    throw invalidArgument("Version invalide : lettres, chiffres, points, tirets (ex. 2026-11-01-1).");
  }
  // Les champs structurels ne sont jamais fournis par l'éditeur : fixés ici.
  const parsed = parseBookingPolicy({
    ...raw,
    approved: true,
    schema_version: 2,
    payment_cycle: "setup_then_authorize_on_acceptance_capture_on_completion",
  });
  if (!parsed) {
    throw invalidArgument(
      "Politique incomplète : version, référence d'approbation, textes d'annulation et de paiement (FR), " +
        "et les trois documents (réservation, conditions générales, confidentialité) avec version, URL https " +
        "et texte FR sont obligatoires."
    );
  }
  return parsed;
}

export const publishBookingPolicy = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const action = data.action;
  const policyRef = db.collection(RUNTIME_FLAGS_COLLECTION).doc("booking_policy");

  if (action === "get") {
    const current = (await policyRef.get()).data() as Record<string, unknown> | undefined;
    const published = editableView(current);
    return {
      published,
      // Point de départ pour l'éditeur quand rien n'est publié : la version
      // d'essai (à relire et re-versionner avant publication finale).
      starter: published ?? editableView(trialBookingPolicy()),
    };
  }

  if (action === "preview") {
    const parsed = parseDraft(data.policy);
    return { valid: true, version: parsed.version, contract_hash: parsed.contract_hash };
  }

  if (action === "publish") {
    const parsed = parseDraft(data.policy);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const result = await db.runTransaction(async (tx) => {
      const current = (await tx.get(policyRef)).data() as Record<string, unknown> | undefined;
      const currentParsed = current ? parseBookingPolicy(current) : null;
      if (currentParsed && currentParsed.version === parsed.version && currentParsed.contract_hash !== parsed.contract_hash) {
        throw failedPrecondition(
          `La version ${parsed.version} est déjà publiée avec un autre texte : changez la version pour publier ce contenu.`
        );
      }
      if (currentParsed && currentParsed.contract_hash === parsed.contract_hash && current?.trial !== true) {
        return { version: parsed.version, contract_hash: parsed.contract_hash, unchanged: true };
      }
      tx.set(policyRef, {
        ...parsed,
        trial: false,
        published_at: now,
        published_by_user_id: ctx.uid,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid,
        actorRole: ctx.role ?? "admin",
        action: "booking_policy_published",
        sourceFunction: "publishBookingPolicy",
        targetId: "system_config/booking_policy",
        metadata: {
          version: parsed.version,
          contractHash: parsed.contract_hash,
          approvalReference: parsed.approval_reference,
          previousVersion: currentParsed?.version ?? null,
          previousWasTrial: current?.trial === true,
        },
      });
      return { version: parsed.version, contract_hash: parsed.contract_hash, unchanged: false };
    });
    return { success: true, ...result };
  }

  throw invalidArgument("Action inconnue.");
});
