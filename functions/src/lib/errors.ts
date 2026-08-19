import { HttpsError } from "firebase-functions/v2/https";

export function unauthenticated(msg = "Authentification requise."): HttpsError {
  return new HttpsError("unauthenticated", msg);
}

export function permissionDenied(msg = "Permission refusée."): HttpsError {
  return new HttpsError("permission-denied", msg);
}

export function notFound(msg = "Ressource introuvable."): HttpsError {
  return new HttpsError("not-found", msg);
}

export function invalidArgument(msg: string): HttpsError {
  return new HttpsError("invalid-argument", msg);
}

export function failedPrecondition(msg: string): HttpsError {
  return new HttpsError("failed-precondition", msg);
}

export function aborted(msg: string): HttpsError {
  return new HttpsError("aborted", msg);
}

export function internal(msg = "Erreur interne."): HttpsError {
  return new HttpsError("internal", msg);
}
