// -----------------------------------------------------------------------------
// observability.ts — Utilitaire centralisé de journalisation OPÉRATIONNELLE
// des opérations financières critiques (Phase 6, Bloc I).
//
// 🎯 OBJECTIF : standardiser les logs financiers critiques SANS introduire un
// framework inutile. S'appuie uniquement sur `firebase-functions/logger`
// (déjà une dépendance du projet, écrit un JSON structuré visible dans Google
// Cloud Logging) et `crypto.randomUUID()` (built-in Node 20) — zéro nouvelle
// dépendance.
//
// ⚠️ Ce module est COMPLÉMENTAIRE à `lib/audit.ts`, jamais un remplacement :
//   - `audit.ts`          -> trace métier persistée (`audit_logs`), source de
//                            vérité pour "qui a fait quoi" (compliance).
//   - `observability.ts`  -> trace OPÉRATIONNELLE structurée (corrélation,
//                            durée, succès/échec, code d'erreur), destinée à
//                            l'observabilité (Cloud Logging / alerting), PAS
//                            à la persistance Firestore.
// Les deux peuvent être utilisés côte à côte au même site d'appel (voir
// processStripeWebhook.ts) : `observability.ts` construit la structure,
// `audit.ts` la persiste dans les métadonnées de l'entrée d'audit.
//
// 🔒 SCHÉMA MINIMAL (imposé par la directive) :
//   correlation_id, operation, result, duration_ms,
//   mission_id?, payment_id?, refund_id?, payout_id?, dispute_id?,
//   provider_event_id?, error_code?
//
// 🔒 SÉCURITÉ : `sanitizeMetadata()` retire récursivement toute clé/valeur
// ressemblant à un secret (clé Stripe, webhook signing secret, en-tête
// Authorization, tokens, données de carte/bancaires, credentials, secrets
// Firebase, objets provider complets) AVANT toute journalisation. Voir
// `test/unit/observability.test.ts` pour la couverture de cette protection.
//
// 🔒 CORRELATION ID : propage un `correlationId` existant si fourni, sinon en
// génère un nouveau côté serveur (`crypto.randomUUID()`). Conçu pour circuler
// tel quel : Cloud Function -> orchestration -> provider -> ledger/audit ->
// log final (voir `resolveCorrelationId`).
//
// 🔒 DURÉE : `duration_ms` n'est JAMAIS inventée — toujours calculée à partir
// d'un timestamp de départ RÉEL capturé via `startFinancialOperationTimer()`
// au tout début de l'opération mesurée.
// -----------------------------------------------------------------------------

import { randomUUID } from "crypto";
import * as logger from "firebase-functions/logger";

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

/** Résultat d'une opération financière — format binaire imposé, jamais un texte libre seul. */
export type FinancialOperationResult = "success" | "failure";

/** Identifiants métier optionnels — les non-applicables sont simplement absents. */
export interface FinancialOperationIdentifiers {
  missionId?: string | null;
  paymentId?: string | null;
  refundId?: string | null;
  payoutId?: string | null;
  disputeId?: string | null;
  providerEventId?: string | null;
}

/** Entrée structurée telle qu'effectivement produite/journalisée (schéma minimal + extras). */
export interface FinancialLogEntry {
  correlation_id: string;
  operation: string;
  result: FinancialOperationResult;
  duration_ms: number;
  mission_id?: string | null;
  payment_id?: string | null;
  refund_id?: string | null;
  payout_id?: string | null;
  dispute_id?: string | null;
  provider_event_id?: string | null;
  error_code?: string | null;
  /** Description humaine COMPLÉMENTAIRE — jamais l'unique source d'information. */
  message?: string | null;
  /** Métadonnées additionnelles libres, TOUJOURS passées par `sanitizeMetadata()` avant emission. */
  metadata?: Record<string, unknown>;
}

export interface LogFinancialOperationInput extends FinancialOperationIdentifiers {
  operation: string;
  result: FinancialOperationResult;
  /** Durée RÉELLEMENT mesurée en millisecondes — jamais inventée. */
  durationMs: number;
  /** Propagé si fourni, sinon un nouveau correlation_id est généré. */
  correlationId?: string | null;
  /** Obligatoire si `result === "failure"`. */
  errorCode?: string | null;
  message?: string | null;
  metadata?: Record<string, unknown> | null;
}

// -----------------------------------------------------------------------------
// Correlation ID — propagation ou génération
// -----------------------------------------------------------------------------

/**
 * Propage un `correlationId` déjà existant (non vide) tel quel, ou en génère
 * un nouveau côté serveur sinon. C'est la SEULE fonction responsable de
 * décider "propager vs générer" — tous les sites d'appel doivent y transiter
 * pour garantir un comportement homogène.
 */
export function resolveCorrelationId(existing?: string | null): string {
  if (typeof existing === "string" && existing.trim().length > 0) {
    return existing;
  }
  return randomUUID();
}

// -----------------------------------------------------------------------------
// Mesure de durée réelle
// -----------------------------------------------------------------------------

/** À appeler au TOUT DÉBUT de l'opération mesurée. Retourne `Date.now()`. */
export function startFinancialOperationTimer(): number {
  return Date.now();
}

/** Calcule la durée réelle écoulée depuis `startedAtMs` (jamais une valeur inventée). */
export function computeDurationMs(startedAtMs: number): number {
  return Math.max(0, Date.now() - startedAtMs);
}

// -----------------------------------------------------------------------------
// Sanitization — interdiction stricte de journaliser des secrets
// -----------------------------------------------------------------------------

const REDACTED = "[REDACTED]";

/**
 * Clés (comparaison insensible à la casse, correspondance EXACTE après
 * normalisation snake/camel -> lower, séparateurs `_`/`-` retirés) considérées
 * comme des identifiants métier AUTORISÉS malgré un nom qui pourrait sembler
 * sensible à un pattern trop large (ex: "payment_token" métier vs "token"
 * générique) — liste volontairement vide pour l'instant : aucun identifiant
 * métier du schéma minimal ne collisionne avec les patterns interdits
 * ci-dessous (mission_id, payment_id, refund_id, payout_id, dispute_id,
 * provider_event_id, error_code, operation, result, correlation_id).
 */
const ALLOWED_KEY_EXACT = new Set<string>([]);

/**
 * Patterns de NOM DE CLÉ interdits — toute clé (à n'importe quel niveau de
 * profondeur) dont le nom normalisé matche un de ces motifs est REDACTED,
 * quelle que soit sa valeur (objet, tableau, primitive).
 */
const FORBIDDEN_KEY_PATTERNS: RegExp[] = [
  /secret/i,
  /apikey/i,
  /api_key/i,
  /authorization/i,
  /auth[-_]?header/i,
  /\btoken\b/i,
  /access[-_]?token/i,
  /refresh[-_]?token/i,
  /password/i,
  /credential/i,
  /private[-_]?key/i,
  /admin[-_]?key/i,
  /service[-_]?account/i,
  /card[-_]?number/i,
  /\bcvc\b/i,
  /\bcvv\b/i,
  /\bpan\b/i, // Primary Account Number (carte)
  /account[-_]?number/i,
  /iban/i,
  /routing[-_]?number/i,
  /bank[-_]?account/i,
  /webhook[-_]?secret/i,
  /signing[-_]?secret/i,
  /raw[-_]?body/i,
  /raw[-_]?payload/i,
  /provider[-_]?object/i,
  /firebase[-_]?(secret|key)/i,
  /stripe[-_]?secret/i,
];

/**
 * Patterns de VALEUR interdits (indépendamment du nom de la clé) — protège
 * contre le cas où une valeur sensible est stockée sous une clé au nom
 * innocent (ex: `{ value: "sk_live_xxx" }`).
 */
const FORBIDDEN_VALUE_PATTERNS: RegExp[] = [
  /^sk_(live|test)_[A-Za-z0-9]+$/, // clé secrète Stripe
  /^rk_(live|test)_[A-Za-z0-9]+$/, // clé restreinte Stripe
  /^whsec_[A-Za-z0-9]+$/, // webhook signing secret Stripe
  /^Bearer\s+\S+$/i, // en-tête Authorization complet
];

function normalizeKey(key: string): string {
  return key.toLowerCase();
}

function isForbiddenKey(key: string): boolean {
  const normalized = normalizeKey(key);
  if (ALLOWED_KEY_EXACT.has(normalized)) return false;
  return FORBIDDEN_KEY_PATTERNS.some((re) => re.test(key));
}

function isForbiddenValue(value: unknown): boolean {
  if (typeof value !== "string") return false;
  return FORBIDDEN_VALUE_PATTERNS.some((re) => re.test(value));
}

const MAX_SANITIZE_DEPTH = 8;

/**
 * Sanitize récursivement un objet/valeur arbitraire AVANT journalisation :
 *   - toute clé dont le nom matche un pattern interdit -> valeur REDACTED
 *     (l'objet/array/valeur entier sous cette clé est retiré, jamais partiel
 *     — un objet provider complet contenant potentiellement des secrets doit
 *     être écarté en bloc dès que sa clé porteuse est nommée en conséquence,
 *     ex: `stripeEvent`, `providerObject`, `rawPayload`).
 *   - toute VALEUR string qui ressemble structurellement à un secret (clé
 *     Stripe, webhook secret, en-tête Authorization complet) -> REDACTED,
 *     même si la clé porteuse a un nom innocent.
 *   - ne mute JAMAIS l'entrée (retourne une copie).
 *   - ne lève JAMAIS d'exception (borne la profondeur de récursion).
 */
export function sanitizeMetadata(input: unknown, depth = 0): unknown {
  if (depth > MAX_SANITIZE_DEPTH) return "[MAX_DEPTH_REDACTED]";
  if (input === null || input === undefined) return input;

  if (Array.isArray(input)) {
    return input.map((item) => sanitizeMetadata(item, depth + 1));
  }

  if (input instanceof Date) return input;

  if (typeof input === "object") {
    const anyInput = input as Record<string, unknown>;
    // Passe-plat opaque pour les Timestamps Firestore (toMillis/toDate) —
    // leurs champs internes ne contiennent aucun secret, itérer dessus ne
    // ferait que produire un objet inutile et fragile pour les tests.
    if (typeof anyInput.toMillis === "function" || typeof anyInput.toDate === "function") {
      return input;
    }
    const output: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(anyInput)) {
      if (isForbiddenKey(key)) {
        output[key] = REDACTED;
        continue;
      }
      if (isForbiddenValue(value)) {
        output[key] = REDACTED;
        continue;
      }
      output[key] = sanitizeMetadata(value, depth + 1);
    }
    return output;
  }

  if (isForbiddenValue(input)) return REDACTED;
  return input;
}

// -----------------------------------------------------------------------------
// Construction + émission de l'entrée structurée
// -----------------------------------------------------------------------------

/**
 * Construit l'entrée structurée SANS l'émettre — pure, facilement testable
 * (voir directive : « teste la structure produite, pas le texte d'un
 * console.log »). Valide la cohérence success/failure et la validité de
 * `duration_ms`.
 */
export function buildFinancialLogEntry(input: LogFinancialOperationInput): FinancialLogEntry {
  if (input.result !== "success" && input.result !== "failure") {
    throw new Error('result doit être "success" ou "failure".');
  }
  if (input.result === "failure" && (!input.errorCode || input.errorCode.trim().length === 0)) {
    throw new Error("error_code est requis lorsque result = failure.");
  }
  if (typeof input.durationMs !== "number" || !Number.isFinite(input.durationMs) || input.durationMs < 0) {
    throw new Error("durationMs doit être un nombre positif réellement mesuré (voir startFinancialOperationTimer).");
  }
  if (!input.operation || input.operation.trim().length === 0) {
    throw new Error("operation est requis.");
  }

  const entry: FinancialLogEntry = {
    correlation_id: resolveCorrelationId(input.correlationId),
    operation: input.operation,
    result: input.result,
    duration_ms: Math.round(input.durationMs),
  };

  if (input.missionId !== undefined && input.missionId !== null) entry.mission_id = input.missionId;
  if (input.paymentId !== undefined && input.paymentId !== null) entry.payment_id = input.paymentId;
  if (input.refundId !== undefined && input.refundId !== null) entry.refund_id = input.refundId;
  if (input.payoutId !== undefined && input.payoutId !== null) entry.payout_id = input.payoutId;
  if (input.disputeId !== undefined && input.disputeId !== null) entry.dispute_id = input.disputeId;
  if (input.providerEventId !== undefined && input.providerEventId !== null) {
    entry.provider_event_id = input.providerEventId;
  }
  if (input.result === "failure") {
    entry.error_code = input.errorCode as string;
  }
  if (input.message !== undefined && input.message !== null) entry.message = input.message;

  if (input.metadata) {
    const sanitized = sanitizeMetadata(input.metadata);
    entry.metadata = sanitized as Record<string, unknown>;
  }

  return entry;
}

/** Émet l'entrée déjà construite via `firebase-functions/logger` (Cloud Logging). */
function emit(entry: FinancialLogEntry): void {
  const severity = entry.result === "success" ? "INFO" : "ERROR";
  // 🔒 `entry.message` (humain, optionnel, potentiellement null) est retiré
  // du spread pour ne jamais entrer en conflit avec le `message` sommaire
  // ci-dessous (LogEntry.message attend `string | undefined`, pas `null`) —
  // il reste néanmoins présent sous sa clé structurée d'origine si besoin
  // via `humanMessage`.
  const { message: humanMessage, ...rest } = entry;
  logger.write({
    severity,
    message: `[financial] ${entry.operation} :: ${entry.result}`,
    ...rest,
    ...(humanMessage ? { humanMessage } : {}),
  });
}

/**
 * API principale : construit l'entrée structurée, la journalise, et la
 * RETOURNE (permet aux appelants de propager le même `correlation_id`
 * résolu vers l'étape suivante — ledger/audit — et aux tests d'asserter
 * directement sur la structure sans dépendre du transport de log).
 */
export function logFinancialOperation(input: LogFinancialOperationInput): FinancialLogEntry {
  const entry = buildFinancialLogEntry(input);
  emit(entry);
  return entry;
}

export interface FinancialOperationExtra {
  correlationId?: string | null;
  message?: string | null;
  metadata?: Record<string, unknown> | null;
}

/**
 * Sucre syntaxique pour le cas succès : `operation` + timestamp de départ
 * (voir `startFinancialOperationTimer`) + identifiants métier applicables.
 */
export function logFinancialSuccess(
  operation: string,
  startedAtMs: number,
  identifiers: FinancialOperationIdentifiers = {},
  extra: FinancialOperationExtra = {}
): FinancialLogEntry {
  return logFinancialOperation({
    operation,
    result: "success",
    durationMs: computeDurationMs(startedAtMs),
    ...identifiers,
    correlationId: extra.correlationId,
    message: extra.message,
    metadata: extra.metadata,
  });
}

/**
 * Sucre syntaxique pour le cas échec : `errorCode` est OBLIGATOIRE (jamais un
 * message libre comme seule source d'information).
 */
export function logFinancialFailure(
  operation: string,
  startedAtMs: number,
  errorCode: string,
  identifiers: FinancialOperationIdentifiers = {},
  extra: FinancialOperationExtra = {}
): FinancialLogEntry {
  return logFinancialOperation({
    operation,
    result: "failure",
    durationMs: computeDurationMs(startedAtMs),
    errorCode,
    ...identifiers,
    correlationId: extra.correlationId,
    message: extra.message,
    metadata: extra.metadata,
  });
}
