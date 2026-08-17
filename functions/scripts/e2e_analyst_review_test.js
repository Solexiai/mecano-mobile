// -----------------------------------------------------------------------------
// e2e_analyst_review_test.js — TEST END-TO-END RÉEL du parcours ANALYSTE
// (approve + reject), exécuté contre le VRAI projet Firebase
// movik-connect-prod, avec les mêmes protocoles réseau qu'un client Flutter
// (Identity Toolkit REST, Firestore REST v1, Cloud Functions Callable HTTP).
//
// Scénarios couverts :
//   A) Pipeline complet chauffeur -> pending_review (x2 comptes jetables)
//   B) Promotion d'un 3e compte jetable au rôle "analyst" (via credentials
//      OAuth CLI, seul mécanisme possible avant qu'un premier analyste/admin
//      existe déjà — même pattern que bootstrap_super_admins.js).
//   C) Scénario APPROVE : analyste approuve driver1 -> status 'approved'.
//   D) Scénario REJECT  : analyste rejette driver2 avec motif -> 'rejected'.
//   E) Tests négatifs de rôle (minimum 7, cumulés avec ceux déjà présents
//      dans e2e_driver_onboarding_test.js) : non-authentifié, customer,
//      driver, sur approveDriver / rejectDriver / requestDriverDocuments /
//      addDriverInternalNote / lecture driver_internal_notes.
//   F) Nettoyage complet : suppression Auth (les 4 comptes) + résidus
//      Firestore via credentials OAuth CLI (users/driver_profiles/notes).
//
// USAGE : node scripts/e2e_analyst_review_test.js
// Sortie : rapport JSON dans scripts/e2e_analyst_report.json (sans secret).
// -----------------------------------------------------------------------------

const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const PROJECT_ID = "movik-connect-prod";
const API_KEY = "AIzaSyCLIvf9Ql4MZvsKGinjnT1caNfj8Ba6oaE"; // apiKey Web public
const REGION = "us-central1";

const IDENTITY_BASE = "https://identitytoolkit.googleapis.com/v1";
const TOKEN_BASE = "https://securetoken.googleapis.com/v1";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const FUNCTIONS_BASE = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net`;

const report = {
  startedAt: new Date().toISOString(),
  projectId: PROJECT_ID,
  environment: "movik-connect-prod (seul projet Firebase existant)",
  accounts: {},
  steps: [],
  finalStatus: "unknown",
};

function log(step, ok, details) {
  const entry = { step, ok, details, at: new Date().toISOString() };
  report.steps.push(entry);
  const icon = ok ? "✅" : "❌";
  console.log(`${icon} [${step}] ${JSON.stringify(details)}`);
}

function decodeJwt(idToken) {
  const payload = idToken.split(".")[1];
  const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
}

// ---- Firestore REST helpers ----
function toFsValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFsValue) } };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  throw new Error(`Type non géré pour Firestore REST: ${typeof v}`);
}

function toFsFields(obj) {
  const fields = {};
  for (const [k, val] of Object.entries(obj)) fields[k] = toFsValue(val);
  return { fields };
}

function fromFsValue(v) {
  if (!v) return null;
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return parseInt(v.integerValue, 10);
  if ("doubleValue" in v) return v.doubleValue;
  if ("nullValue" in v) return null;
  if ("timestampValue" in v) return v.timestampValue;
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(fromFsValue);
  return v;
}

function fromFsDoc(doc) {
  const out = {};
  for (const [k, v] of Object.entries(doc.fields || {})) out[k] = fromFsValue(v);
  return out;
}

async function firestoreWrite(collectionDoc, idToken, dataObj, { maskFields } = {}) {
  const url = new URL(`${FIRESTORE_BASE}/${collectionDoc}`);
  (maskFields || Object.keys(dataObj)).forEach((f) => url.searchParams.append("updateMask.fieldPaths", f));
  const res = await fetch(url.toString(), {
    method: "PATCH",
    headers: { Authorization: `Bearer ${idToken}`, "Content-Type": "application/json" },
    body: JSON.stringify(toFsFields(dataObj)),
  });
  const body = await res.json();
  return { status: res.status, ok: res.ok, body };
}

async function firestoreRead(collectionDoc, idToken) {
  const res = await fetch(`${FIRESTORE_BASE}/${collectionDoc}`, {
    headers: idToken ? { Authorization: `Bearer ${idToken}` } : {},
  });
  const body = await res.json();
  return { status: res.status, ok: res.ok, body };
}

async function firestoreDelete(collectionDoc, idToken) {
  const res = await fetch(`${FIRESTORE_BASE}/${collectionDoc}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${idToken}` },
  });
  return { status: res.status, ok: res.ok };
}

// ---- Cloud Functions callable ----
async function callFunction(name, idToken, data = {}) {
  const res = await fetch(`${FUNCTIONS_BASE}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, body };
}

// ---- Identity Toolkit (Auth) ----
async function signUp(email, password) {
  const res = await fetch(`${IDENTITY_BASE}/accounts:signUp?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  return res.json();
}

async function refreshIdToken(refreshToken) {
  const res = await fetch(`${TOKEN_BASE}/token?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}`,
  });
  return res.json();
}

async function deleteAccountSelf(idToken) {
  const res = await fetch(`${IDENTITY_BASE}/accounts:delete?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ idToken }),
  });
  return { status: res.status, ok: res.ok, body: await res.json().catch(() => ({})) };
}

// ---- OAuth CLI credentials (Admin custom claims — voir bootstrap_super_admins.js) ----
function loadCliCredentials() {
  const configPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  const raw = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const tokens = raw.tokens;
  if (!tokens || !tokens.refresh_token) {
    throw new Error("Aucun refresh_token trouvé dans la session `firebase login`.");
  }
  return tokens;
}

async function getCliAdminClients() {
  const tokens = loadCliCredentials();
  const CLI_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
  const CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"; // public, voir bootstrap_super_admins.js
  const { OAuth2Client } = require("google-auth-library");
  const oauth2Client = new OAuth2Client(CLI_CLIENT_ID, CLI_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: tokens.refresh_token });

  const admin = require("firebase-admin");
  const appName = `e2e-analyst-admin-${Date.now()}`;
  const app = admin.initializeApp(
    {
      projectId: PROJECT_ID,
      credential: {
        getAccessToken: async () => {
          const res = await oauth2Client.getAccessToken();
          return { access_token: res.token, expires_in: 3600 };
        },
      },
    },
    appName
  );

  const { Firestore } = require("@google-cloud/firestore");
  const firestoreClient = new Firestore({ projectId: PROJECT_ID, authClient: oauth2Client });

  return { authAdmin: app.auth(), firestoreClient, app };
}

// -----------------------------------------------------------------------
// Helper : amène un compte chauffeur jetable jusqu'à 'pending_review'.
// Reproduit le pipeline déjà validé par e2e_driver_onboarding_test.js.
// -----------------------------------------------------------------------
async function bootstrapDriverToPendingReview(label, stamp) {
  const email = `e2e-test-${label}-${stamp}@movik-test.invalid`;
  const password = crypto.randomBytes(12).toString("base64url");
  const fullName = `E2E TEST ${label.toUpperCase()} — safe to delete`;

  const signUpRes = await signUp(email, password);
  if (signUpRes.error) throw new Error(`signUp(${label}) failed: ${JSON.stringify(signUpRes.error)}`);
  const uid = signUpRes.localId;
  let idToken = signUpRes.idToken;
  const refreshToken = signUpRes.refreshToken;

  await firestoreWrite(`users/${uid}`, idToken, {
    uid,
    email,
    full_name: fullName,
    roles: ["customer"],
    created_at: new Date(),
    is_disabled: false,
    email_verified: false,
  });

  const registerRes = await callFunction("registerAsDriver", idToken, {});
  if (!registerRes.ok || registerRes.body.result?.success !== true) {
    throw new Error(`registerAsDriver(${label}) failed: ${JSON.stringify(registerRes.body)}`);
  }

  const refreshRes = await refreshIdToken(refreshToken);
  if (refreshRes.error) throw new Error(`refresh(${label}) failed: ${JSON.stringify(refreshRes.error)}`);
  idToken = refreshRes.id_token;

  await firestoreWrite(`driver_profiles/${uid}`, idToken, {
    uid,
    full_name: fullName,
    city: "Montréal, QC",
    status: "registration_incomplete",
    service_radius_km: 25,
    accepted_vehicle_categories: ["pickup_truck"],
    accepted_item_category_keys: ["cat_furniture"],
    rating: 0,
    completed_missions: 0,
    created_at: new Date(),
    identity_verified: false,
    vehicle_verified: false,
    online_status: "offline",
  });

  const vehicleId = crypto.randomUUID();
  await firestoreWrite(`driver_vehicles/${vehicleId}`, idToken, {
    id: vehicleId,
    driver_id: uid,
    category: "pickup_truck",
    make_model: "Ford F-150",
    year: 2020,
    plate: `E2E-${label.slice(0, 3).toUpperCase()}`,
    max_payload_kg: 900,
    is_verified: false,
    created_at: new Date(),
  });

  const submitRes = await callFunction("submitDriverForReview", idToken, {});
  if (!submitRes.ok || submitRes.body.result?.status !== "pending_review") {
    throw new Error(`submitDriverForReview(${label}) failed: ${JSON.stringify(submitRes.body)}`);
  }

  return { label, email, uid, idToken, refreshToken, vehicleId };
}

async function main() {
  const stamp = Date.now();

  // -----------------------------------------------------------------------
  // ÉTAPE A — Bootstrap des 2 comptes chauffeurs jusqu'à pending_review
  // -----------------------------------------------------------------------
  let driver1, driver2, customer, analyst;
  try {
    driver1 = await bootstrapDriverToPendingReview("driver1", stamp);
    log("A1_driver1_bootstrapped_to_pending_review", true, { uid: driver1.uid });
  } catch (e) {
    log("A1_driver1_bootstrapped_to_pending_review", false, { error: String(e) });
    report.finalStatus = "FAILED_AT_DRIVER1_BOOTSTRAP";
    return finish();
  }

  try {
    driver2 = await bootstrapDriverToPendingReview("driver2", stamp);
    log("A2_driver2_bootstrapped_to_pending_review", true, { uid: driver2.uid });
  } catch (e) {
    log("A2_driver2_bootstrapped_to_pending_review", false, { error: String(e) });
    report.finalStatus = "FAILED_AT_DRIVER2_BOOTSTRAP";
    return finish(driver1);
  }

  // -----------------------------------------------------------------------
  // ÉTAPE B — Compte customer jetable (pour tests négatifs de rôle)
  // -----------------------------------------------------------------------
  const customerEmail = `e2e-test-customer-${stamp}@movik-test.invalid`;
  const customerPassword = crypto.randomBytes(12).toString("base64url");
  const customerSignUp = await signUp(customerEmail, customerPassword);
  customer = { email: customerEmail, uid: customerSignUp.localId, idToken: customerSignUp.idToken };
  await firestoreWrite(`users/${customer.uid}`, customer.idToken, {
    uid: customer.uid,
    email: customerEmail,
    full_name: "E2E TEST CUSTOMER — safe to delete",
    roles: ["customer"],
    created_at: new Date(),
    is_disabled: false,
    email_verified: false,
  });
  log("B_customer_account_created", !!customer.uid, { uid: customer.uid });

  // -----------------------------------------------------------------------
  // ÉTAPE C — Compte analyste jetable : signUp normal, puis promotion via
  // credentials OAuth CLI (setCustomUserClaims), exactement le même
  // mécanisme que bootstrap_super_admins.js.
  // -----------------------------------------------------------------------
  const analystEmail = `e2e-test-analyst-${stamp}@movik-test.invalid`;
  const analystPassword = crypto.randomBytes(12).toString("base64url");
  const analystSignUp = await signUp(analystEmail, analystPassword);
  const analystUid = analystSignUp.localId;
  const analystRefreshToken = analystSignUp.refreshToken;

  let cliAdmin;
  try {
    cliAdmin = await getCliAdminClients();
    await cliAdmin.authAdmin.setCustomUserClaims(analystUid, { role: "analyst", roles: ["analyst"] });
    log("C1_analyst_claim_assigned_via_oauth_cli", true, { uid: analystUid });
  } catch (e) {
    log("C1_analyst_claim_assigned_via_oauth_cli", false, { error: String(e) });
    report.finalStatus = "FAILED_AT_ANALYST_CLAIM";
    return finish(driver1, driver2, customer, { uid: analystUid, idToken: analystSignUp.idToken });
  }

  const analystRefreshRes = await refreshIdToken(analystRefreshToken);
  const analystIdToken = analystRefreshRes.id_token;
  const analystClaims = decodeJwt(analystIdToken);
  analyst = { email: analystEmail, uid: analystUid, idToken: analystIdToken };
  log("C2_analyst_claim_visible_after_refresh", analystClaims.role === "analyst", {
    role: analystClaims.role,
    roles: analystClaims.roles,
  });

  report.accounts = {
    driver1: { email: driver1.email, uid: driver1.uid },
    driver2: { email: driver2.email, uid: driver2.uid },
    customer: { email: customer.email, uid: customer.uid },
    analyst: { email: analyst.email, uid: analyst.uid },
  };

  // -----------------------------------------------------------------------
  // TESTS NÉGATIFS DE RÔLE — AVANT toute action analyste légitime (état
  // driver1/driver2 = pending_review, aucune tentative n'a encore réussi).
  // -----------------------------------------------------------------------
  const unauthApprove = await callFunction("approveDriver", null, { driverId: driver1.uid });
  log("N1_unauthenticated_cannot_call_approveDriver", unauthApprove.status === 401 || unauthApprove.body?.error?.status === "UNAUTHENTICATED", {
    status: unauthApprove.status,
    error: unauthApprove.body.error || null,
  });

  const customerApprove = await callFunction("approveDriver", customer.idToken, { driverId: driver1.uid });
  log("N2_customer_cannot_call_approveDriver", customerApprove.body?.error?.status === "PERMISSION_DENIED", {
    status: customerApprove.status,
    error: customerApprove.body.error || null,
  });

  const driverApprove = await callFunction("approveDriver", driver1.idToken, { driverId: driver1.uid });
  log("N3_driver_cannot_call_approveDriver_on_self", driverApprove.body?.error?.status === "PERMISSION_DENIED", {
    status: driverApprove.status,
    error: driverApprove.body.error || null,
  });

  const customerRequestDocs = await callFunction("requestDriverDocuments", customer.idToken, {
    driverId: driver1.uid,
    reason: "test négatif",
  });
  log("N4_customer_cannot_call_requestDriverDocuments", customerRequestDocs.body?.error?.status === "PERMISSION_DENIED", {
    status: customerRequestDocs.status,
    error: customerRequestDocs.body.error || null,
  });

  const customerAddNote = await callFunction("addDriverInternalNote", customer.idToken, {
    driverId: driver1.uid,
    text: "tentative non autorisée",
  });
  log("N5_customer_cannot_call_addDriverInternalNote", customerAddNote.body?.error?.status === "PERMISSION_DENIED", {
    status: customerAddNote.status,
    error: customerAddNote.body.error || null,
  });

  const driverRejectOther = await callFunction("rejectDriver", driver2.idToken, {
    driverId: driver1.uid,
    reason: "tentative malveillante",
  });
  log("N6_driver_cannot_call_rejectDriver_on_another_driver", driverRejectOther.body?.error?.status === "PERMISSION_DENIED", {
    status: driverRejectOther.status,
    error: driverRejectOther.body.error || null,
  });

  // -----------------------------------------------------------------------
  // ÉTAPE D — SCÉNARIO APPROVE : l'analyste ajoute une note puis approuve driver1.
  // -----------------------------------------------------------------------
  const addNoteRes = await callFunction("addDriverInternalNote", analyst.idToken, {
    driverId: driver1.uid,
    text: "Dossier vérifié : permis + véhicule conformes. E2E test.",
  });
  log("D1_analyst_adds_internal_note", addNoteRes.ok && addNoteRes.body.result?.success === true, {
    status: addNoteRes.status,
    result: addNoteRes.body.result,
    error: addNoteRes.body.error || null,
  });
  const noteId = addNoteRes.body.result?.noteId;

  // Le chauffeur concerné ne doit PAS pouvoir lire cette note (confidentialité analyste).
  if (noteId) {
    const driverReadsNote = await firestoreRead(`driver_internal_notes/${noteId}`, driver1.idToken);
    log("D2_negative_driver_cannot_read_own_internal_note", driverReadsNote.status === 403, {
      status: driverReadsNote.status,
    });
  }

  const approveRes = await callFunction("approveDriver", analyst.idToken, { driverId: driver1.uid });
  log("D3_analyst_approves_driver1", approveRes.ok && approveRes.body.result?.success === true, {
    status: approveRes.status,
    result: approveRes.body.result,
    error: approveRes.body.error || null,
  });

  const driver1AfterApprove = await firestoreRead(`driver_profiles/${driver1.uid}`, driver1.idToken);
  const driver1Data = driver1AfterApprove.ok ? fromFsDoc(driver1AfterApprove.body) : null;
  log("D4_driver1_status_is_approved", driver1Data?.status === "approved", {
    status: driver1Data?.status,
    approved_by_user_id: driver1Data?.approved_by_user_id,
  });

  // Négatif : ré-approuver un chauffeur déjà approuvé doit échouer.
  const doubleApprove = await callFunction("approveDriver", analyst.idToken, { driverId: driver1.uid });
  log("N7_negative_double_approve_blocked", doubleApprove.body?.error?.status === "FAILED_PRECONDITION", {
    status: doubleApprove.status,
    error: doubleApprove.body.error || null,
  });

  // Une fois approuvé, driver1 peut passer en ligne (Switch de DriverStatusScreen).
  const goOnline = await firestoreWrite(
    `driver_profiles/${driver1.uid}`,
    driver1.idToken,
    { online_status: "online" },
    { maskFields: ["online_status"] }
  );
  log("D5_approved_driver1_can_go_online", goOnline.ok, { status: goOnline.status });

  // -----------------------------------------------------------------------
  // ÉTAPE E — SCÉNARIO REJECT : l'analyste rejette driver2 avec motif.
  // -----------------------------------------------------------------------
  const rejectRes = await callFunction("rejectDriver", analyst.idToken, {
    driverId: driver2.uid,
    reason: "Photo du permis illisible — E2E test.",
  });
  log("E1_analyst_rejects_driver2", rejectRes.ok && rejectRes.body.result?.success === true, {
    status: rejectRes.status,
    result: rejectRes.body.result,
    error: rejectRes.body.error || null,
  });

  const driver2AfterReject = await firestoreRead(`driver_profiles/${driver2.uid}`, driver2.idToken);
  const driver2Data = driver2AfterReject.ok ? fromFsDoc(driver2AfterReject.body) : null;
  log("E2_driver2_status_is_rejected_with_reason", driver2Data?.status === "rejected" && !!driver2Data?.rejection_reason, {
    status: driver2Data?.status,
    rejection_reason: driver2Data?.rejection_reason,
  });

  // Négatif : requestDriverDocuments depuis 'rejected' n'est pas un statut de
  // départ autorisé (ALLOWED_PREVIOUS_STATUSES = pending_review/documents_required/approved).
  const requestDocsOnRejected = await callFunction("requestDriverDocuments", analyst.idToken, {
    driverId: driver2.uid,
    reason: "test négatif transition invalide",
  });
  log("N8_negative_requestDriverDocuments_from_rejected_blocked", requestDocsOnRejected.body?.error?.status === "FAILED_PRECONDITION", {
    status: requestDocsOnRejected.status,
    error: requestDocsOnRejected.body.error || null,
  });

  report.finalStatus = report.steps.every((s) => s.ok) ? "ALL_PASSED" : "SOME_FAILED";

  return finish(driver1, driver2, customer, analyst, cliAdmin, noteId);
}

async function finish(driver1, driver2, customer, analyst, cliAdmin, noteId) {
  // -----------------------------------------------------------------------
  // NETTOYAGE COMPLET
  // -----------------------------------------------------------------------
  const cleanupUids = [];

  if (driver1) {
    if (driver1.vehicleId) {
      const del = await firestoreDelete(`driver_vehicles/${driver1.vehicleId}`, driver1.idToken);
      log("Z1_cleanup_driver1_vehicle_deleted", del.ok, { status: del.status });
    }
    const del = await deleteAccountSelf(driver1.idToken);
    log("Z2_cleanup_driver1_auth_deleted", del.ok, { status: del.status });
    cleanupUids.push(driver1.uid);
  }

  if (driver2) {
    if (driver2.vehicleId) {
      const del = await firestoreDelete(`driver_vehicles/${driver2.vehicleId}`, driver2.idToken);
      log("Z3_cleanup_driver2_vehicle_deleted", del.ok, { status: del.status });
    }
    const del = await deleteAccountSelf(driver2.idToken);
    log("Z4_cleanup_driver2_auth_deleted", del.ok, { status: del.status });
    cleanupUids.push(driver2.uid);
  }

  if (customer) {
    const del = await deleteAccountSelf(customer.idToken);
    log("Z5_cleanup_customer_auth_deleted", del.ok, { status: del.status });
    cleanupUids.push(customer.uid);
  }

  if (analyst) {
    const del = await deleteAccountSelf(analyst.idToken);
    log("Z6_cleanup_analyst_auth_deleted", del.ok, { status: del.status });
    cleanupUids.push(analyst.uid);
  }

  // Résidus Firestore : users/{uid} et driver_profiles/{uid} ont
  // `allow delete: if false` inconditionnel côté client — nettoyage via
  // credentials OAuth CLI (même mécanisme que cleanup_e2e_test_driver.js).
  // driver_internal_notes est également immuable côté client (write: if false).
  if (cliAdmin) {
    try {
      const collections = ["users", "driver_profiles"];
      for (const col of collections) {
        for (const uid of cleanupUids) {
          const ref = cliAdmin.firestoreClient.collection(col).doc(uid);
          const snap = await ref.get();
          if (snap.exists) {
            await ref.delete();
          }
        }
      }
      if (noteId) {
        await cliAdmin.firestoreClient.collection("driver_internal_notes").doc(noteId).delete();
      }
      log("Z7_cleanup_firestore_residuals_via_oauth_cli", true, {
        collections_cleaned: ["users", "driver_profiles", "driver_internal_notes"],
        uids: cleanupUids,
      });
    } catch (e) {
      log("Z7_cleanup_firestore_residuals_via_oauth_cli", false, { error: String(e) });
    } finally {
      try {
        await cliAdmin.app.delete();
      } catch (_) {
        /* noop */
      }
    }
  }

  report.finishedAt = new Date().toISOString();
  const reportPath = path.join(__dirname, "e2e_analyst_report.json");
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\n📄 Rapport complet écrit dans ${reportPath}`);
  console.log(`\n🏁 STATUT FINAL: ${report.finalStatus}`);
  const failed = report.steps.filter((s) => !s.ok);
  if (failed.length > 0) {
    console.log(`\n❌ ${failed.length} étape(s) en échec:`);
    failed.forEach((s) => console.log(`   - ${s.step}`));
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error("💥 Erreur fatale du script de test:", err);
  process.exitCode = 1;
});
