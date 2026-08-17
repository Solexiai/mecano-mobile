// -----------------------------------------------------------------------------
// e2e_driver_onboarding_test.js — TEST END-TO-END RÉEL du parcours chauffeur,
// exécuté contre le VRAI projet Firebase movik-connect-prod, en utilisant
// EXACTEMENT les mêmes protocoles réseau que le client Flutter :
//   - Identity Toolkit REST (signUp/token) — équivalent de firebase_auth
//   - Firestore REST v1 — équivalent de cloud_firestore
//   - Cloud Functions Callable HTTP — équivalent de cloud_functions
//
// Aucun Admin SDK, aucune clé privée : ce script n'a PAS plus de pouvoir
// qu'un vrai client Flutter. C'est précisément ce qui rend le test valable
// (il prouve que les Security Rules + Cloud Functions se comportent
// correctement pour un vrai utilisateur, pas seulement que le code compile).
//
// COMPTE DE TEST : jetable, généré aléatoirement à chaque exécution, adresse
// sous le domaine réservé aux tests .invalid (RFC 2606) — jamais un vrai
// compte client. Le mot de passe n'est jamais affiché dans les logs/rapport.
//
// USAGE : node scripts/e2e_driver_onboarding_test.js
// Sortie : rapport JSON dans scripts/e2e_report.json (sans secret).
// -----------------------------------------------------------------------------

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "movik-connect-prod";
const API_KEY = "AIzaSyCLIvf9Ql4MZvsKGinjnT1caNfj8Ba6oaE"; // apiKey Web public (voir firebase_options.dart)
const REGION = "us-central1";

const IDENTITY_BASE = "https://identitytoolkit.googleapis.com/v1";
const TOKEN_BASE = "https://securetoken.googleapis.com/v1";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const FUNCTIONS_BASE = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net`;

const report = {
  startedAt: new Date().toISOString(),
  projectId: PROJECT_ID,
  environment: "movik-connect-prod (seul projet Firebase existant — voir roadmap dev/staging)",
  testAccount: {},
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

// ---- Firestore REST helpers (typed values) ----
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

async function main() {
  const stamp = Date.now();
  const email = `e2e-test-driver-${stamp}@movik-test.invalid`;
  const password = crypto.randomBytes(12).toString("base64url"); // jamais loggé
  const fullName = "E2E TEST DRIVER — safe to delete";

  report.testAccount = { email, environment: PROJECT_ID, createdAtStep: "1. Firebase Authentication signUp" };

  // ---------------------------------------------------------------------
  // ÉTAPE 1 — Firebase Authentication : création du compte
  // ---------------------------------------------------------------------
  const signUpRes = await signUp(email, password);
  if (signUpRes.error) {
    log("1_auth_signup", false, { error: signUpRes.error });
    report.finalStatus = "FAILED_AT_SIGNUP";
    return finish();
  }
  const uid = signUpRes.localId;
  let idToken = signUpRes.idToken;
  const refreshToken = signUpRes.refreshToken;
  report.testAccount.uid = uid;
  log("1_auth_signup", true, { uid, emailVerified: signUpRes.emailVerified === true, hasIdToken: !!idToken, hasRefreshToken: !!refreshToken });

  // ---------------------------------------------------------------------
  // NEGATIF — un client ne doit pas pouvoir s'attribuer admin/analyst/super_admin
  // à la création de users/{uid}.
  // ---------------------------------------------------------------------
  const maliciousUserCreate = await firestoreWrite(`users/${uid}`, idToken, {
    uid,
    email,
    full_name: fullName,
    roles: ["super_admin"],
    created_at: new Date(),
    is_disabled: false,
    email_verified: false,
  });
  log("2_negative_user_self_escalation_blocked", maliciousUserCreate.status === 403, {
    expected: 403,
    got: maliciousUserCreate.status,
    body: maliciousUserCreate.body.error || null,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 3 — Création légitime de users/{uid} (roles=['customer'])
  // ---------------------------------------------------------------------
  const userCreate = await firestoreWrite(`users/${uid}`, idToken, {
    uid,
    email,
    full_name: fullName,
    roles: ["customer"],
    created_at: new Date(),
    is_disabled: false,
    email_verified: false,
  });
  log("3_user_document_created", userCreate.ok, { status: userCreate.status, error: userCreate.body.error || null });

  const userRead = await firestoreRead(`users/${uid}`, idToken);
  const userData = userRead.ok ? fromFsDoc(userRead.body) : null;
  log("3b_user_document_verified", userRead.ok && Array.isArray(userData?.roles) && userData.roles[0] === "customer", {
    uid: userData?.uid,
    email: userData?.email,
    roles: userData?.roles,
    created_at: userData?.created_at,
  });

  // ---------------------------------------------------------------------
  // NEGATIF — impossible de créer driver_profiles/{uid} sans le claim driver
  // ---------------------------------------------------------------------
  const preClaimProfileAttempt = await firestoreWrite(`driver_profiles/${uid}`, idToken, {
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
  log("4_negative_driver_profile_without_claim_blocked", preClaimProfileAttempt.status === 403, {
    expected: 403,
    got: preClaimProfileAttempt.status,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 5 — registerAsDriver (Cloud Function)
  // ---------------------------------------------------------------------
  const registerRes = await callFunction("registerAsDriver", idToken, {});
  const registerOk = registerRes.ok && registerRes.body.result?.success === true;
  log("5_registerAsDriver", registerOk, { status: registerRes.status, result: registerRes.body.result, error: registerRes.body.error || null });

  // NEGATIF — registerAsDriver sans authentification doit échouer.
  const registerUnauth = await callFunction("registerAsDriver", null, {});
  log("5b_negative_registerAsDriver_unauthenticated_blocked", registerUnauth.status === 401 || registerUnauth.body?.error?.status === "UNAUTHENTICATED", {
    status: registerUnauth.status,
    error: registerUnauth.body.error || null,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 6 — refreshClaims (équivalent getIdTokenResult(force:true))
  // ---------------------------------------------------------------------
  const refreshRes = await refreshIdToken(refreshToken);
  if (refreshRes.error) {
    log("6_refresh_claims", false, { error: refreshRes.error });
    report.finalStatus = "FAILED_AT_REFRESH";
    return finish(uid, idToken);
  }
  idToken = refreshRes.id_token;
  const claims = decodeJwt(idToken);
  const hasDriverClaim = Array.isArray(claims.roles) && claims.roles.includes("driver");
  log("6_refresh_claims", hasDriverClaim, { role: claims.role, roles: claims.roles });

  // ---------------------------------------------------------------------
  // NEGATIF — tentative d'auto-approbation (status='approved') doit échouer
  // ---------------------------------------------------------------------
  const selfApproveAttempt = await firestoreWrite(`driver_profiles/${uid}`, idToken, {
    uid,
    full_name: fullName,
    city: "Montréal, QC",
    status: "approved", // <-- tentative malveillante
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
  log("7_negative_self_approve_blocked", selfApproveAttempt.status === 403, {
    expected: 403,
    got: selfApproveAttempt.status,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 8 — Création légitime driver_profiles/{uid}
  // ---------------------------------------------------------------------
  const profileCreate = await firestoreWrite(`driver_profiles/${uid}`, idToken, {
    uid,
    full_name: fullName,
    city: "Montréal, QC",
    status: "registration_incomplete",
    service_radius_km: 25,
    accepted_vehicle_categories: ["pickup_truck"],
    accepted_item_category_keys: ["cat_furniture", "cat_pallets"],
    rating: 0,
    completed_missions: 0,
    created_at: new Date(),
    identity_verified: false,
    vehicle_verified: false,
    online_status: "offline",
  });
  log("8_driver_profile_created", profileCreate.ok, { status: profileCreate.status, error: profileCreate.body.error || null });

  // ---------------------------------------------------------------------
  // NEGATIF — driver_vehicles avec is_verified=true doit échouer
  // ---------------------------------------------------------------------
  const vehicleId = crypto.randomUUID();
  const maliciousVehicle = await firestoreWrite(`driver_vehicles/${vehicleId}`, idToken, {
    id: vehicleId,
    driver_id: uid,
    category: "pickup_truck",
    make_model: "Ford F-150",
    year: 2020,
    plate: "E2E-TEST",
    max_payload_kg: 900,
    is_verified: true, // <-- tentative malveillante
    created_at: new Date(),
  });
  log("9_negative_vehicle_self_verify_blocked", maliciousVehicle.status === 403, {
    expected: 403,
    got: maliciousVehicle.status,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 10 — Création légitime driver_vehicles/{id} (is_verified=false)
  // ---------------------------------------------------------------------
  const vehicleCreate = await firestoreWrite(`driver_vehicles/${vehicleId}`, idToken, {
    id: vehicleId,
    driver_id: uid,
    category: "pickup_truck",
    make_model: "Ford F-150",
    year: 2020,
    plate: "E2E-TEST",
    max_payload_kg: 900,
    is_verified: false,
    created_at: new Date(),
  });
  log("10_driver_vehicle_created", vehicleCreate.ok, { status: vehicleCreate.status, error: vehicleCreate.body.error || null });
  report.testAccount.vehicleId = vehicleId;

  const vehicleRead = await firestoreRead(`driver_vehicles/${vehicleId}`, idToken);
  const vehicleData = vehicleRead.ok ? fromFsDoc(vehicleRead.body) : null;
  log("10b_driver_vehicle_verified", vehicleData?.is_verified === false, {
    category: vehicleData?.category,
    is_verified: vehicleData?.is_verified,
  });

  // ---------------------------------------------------------------------
  // NEGATIF — customer/driver ne peut pas appeler approveDriver/rejectDriver
  // ---------------------------------------------------------------------
  const approveAttempt = await callFunction("approveDriver", idToken, { driverId: uid });
  log("11_negative_driver_cannot_approve", approveAttempt.body?.error?.status === "PERMISSION_DENIED", {
    status: approveAttempt.status,
    error: approveAttempt.body.error || null,
  });

  const rejectAttempt = await callFunction("rejectDriver", idToken, { driverId: uid, reason: "test" });
  log("12_negative_driver_cannot_reject", rejectAttempt.body?.error?.status === "PERMISSION_DENIED", {
    status: rejectAttempt.status,
    error: rejectAttempt.body.error || null,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 13 — submitDriverForReview (transition registration_incomplete -> pending_review)
  // ---------------------------------------------------------------------
  const submitReviewRes = await callFunction("submitDriverForReview", idToken, {});
  const submitOk = submitReviewRes.ok && submitReviewRes.body.result?.status === "pending_review";
  log("13_submitDriverForReview", submitOk, { status: submitReviewRes.status, result: submitReviewRes.body.result, error: submitReviewRes.body.error || null });

  // ---------------------------------------------------------------------
  // NEGATIF — transition interdite : pending_review -> pending_review (re-soumission)
  // ---------------------------------------------------------------------
  const secondSubmitAttempt = await callFunction("submitDriverForReview", idToken, {});
  log("14_negative_resubmit_from_pending_review_blocked", secondSubmitAttempt.body?.error?.status === "FAILED_PRECONDITION", {
    status: secondSubmitAttempt.status,
    error: secondSubmitAttempt.body.error || null,
  });

  // ---------------------------------------------------------------------
  // ÉTAPE 15 — Vérification finale de driver_profiles/{uid}
  // ---------------------------------------------------------------------
  const finalRead = await firestoreRead(`driver_profiles/${uid}`, idToken);
  const finalData = finalRead.ok ? fromFsDoc(finalRead.body) : null;
  log("15_final_status_verified", finalData?.status === "pending_review", {
    status: finalData?.status,
    submitted_for_review_at: finalData?.submitted_for_review_at,
    accepted_vehicle_categories: finalData?.accepted_vehicle_categories,
  });

  report.testAccount.finalDriverStatus = finalData?.status;
  report.finalStatus = report.steps.every((s) => s.ok) ? "ALL_PASSED" : "SOME_FAILED";

  return finish(uid, idToken, vehicleId);
}

async function finish(uid, idToken, vehicleId) {
  // -----------------------------------------------------------------------
  // NETTOYAGE PARTIEL (niveau client, sans Admin SDK) :
  // - driver_vehicles/{id} : suppression autorisée pour le propriétaire (règle
  //   `allow delete: if resource.data.driver_id == uid() && isDriver()`).
  // - Compte Firebase Auth : auto-suppression via accounts:delete.
  // - users/{uid} et driver_profiles/{uid} : `allow delete: if false`
  //   INCONDITIONNEL dans firestore.rules (aucune Cloud Function de
  //   suppression n'existe non plus) — CES DOCUMENTS NE PEUVENT PAS être
  //   supprimés par un client, même admin. Un script séparé utilisant les
  //   credentials OAuth de la CLI (cf. bootstrap_super_admins.js) sera requis
  //   pour un nettoyage complet — voir cleanup_e2e_test_driver.js.
  // -----------------------------------------------------------------------
  if (uid && idToken && vehicleId) {
    const delVehicle = await firestoreDelete(`driver_vehicles/${vehicleId}`, idToken);
    log("16_cleanup_vehicle_deleted", delVehicle.ok, { status: delVehicle.status });
  }
  if (uid && idToken) {
    const delAccount = await deleteAccountSelf(idToken);
    log("17_cleanup_auth_account_deleted", delAccount.ok, { status: delAccount.status });
    report.testAccount.authAccountDeleted = delAccount.ok;
    report.testAccount.firestoreDocsRemainingForManualCleanup = [`users/${uid}`, `driver_profiles/${uid}`];
  }

  report.finishedAt = new Date().toISOString();
  const reportPath = path.join(__dirname, "e2e_report.json");
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
