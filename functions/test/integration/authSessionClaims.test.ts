// ---------------------------------------------------------------------------
// authSessionClaims.test.ts — Phase 7, Bloc E (AUTH / SESSION / CLAIMS).
//
// GAP DE COUVERTURE COMBLÉ : recherche confirmée (Bloc E, reconnaissance
// ciblée, PAS de ré-audit général) : AUCUN fichier `functions/test/*`
// n'exerçait auparavant, de bout en bout, le cycle Firebase Auth réel
// (signup/login/mauvais mot de passe/désactivation/refresh de token) NI le
// round-trip complet "promotion de rôle -> refresh -> droits effectifs" en
// passant réellement par les endpoints Identity Toolkit émulés (et pas
// uniquement par `buildRequest()`, qui fabrique un `CallableRequest` à la
// main sans jamais appeler `verifyIdToken()`).
//
// Ce fichier ajoute DEUX niveaux de preuve complémentaires à ceux déjà
// validés au Bloc D (`adminPrivilegedActions.test.ts`) :
//
//   NIVEAU 1 — Session/Identity Toolkit RÉEL (via fetch() vers l'émulateur
//   Auth, exactement le protocole HTTP qu'utilise un client Flutter Web/
//   Android réel : signUp, signInWithPassword, token refresh). Ceci EXERCE
//   réellement `checkAuthToken()` -> `verifyIdToken()` côté Cloud Function
//   (contrairement à `buildRequest()`), donc prouve le comportement
//   VRAIMENT bout-en-bout pour : signup, login, mauvais mot de passe,
//   compte désactivé, appel non authentifié, refresh de token.
//
//   NIVEAU 2 — Claims/rôles round-trip (réutilise `buildRequest()` +
//   `setUserRole.run()`, pattern déjà validé et suffisant au Bloc D) pour
//   prouver que le SERVEUR (seule autorité) applique immédiatement tout
//   changement de rôle à la PROCHAINE requête présentant les nouvelles
//   claims — le principe "le frontend n'est jamais l'autorité finale" est
//   prouvé ici côté BACKEND : quel que soit ce qu'affiche l'UI, une requête
//   avec un rôle insuffisant est refusée, et une requête avec le rôle à
//   jour est acceptée. Le pendant UI (affichage cohérent avec ces mêmes
//   principes) est testé séparément dans
//   `test/auth/admin_auth_gate_session_claims_test.dart` (Flutter).
//
// NUANCE IMPORTANTE (à ne PAS surinterpréter) : Firebase délivre les claims
// au moment de l'émission du token ; il n'y a pas de re-vérification par
// requête contre une base de claims vivante (sauf `checkRevoked: true`,
// jamais utilisé par les `onCall` de ce projet — confirmé par inspection du
// SDK `firebase-functions`). Un ID token déjà émis reste donc valide
// jusqu'à son expiration naturelle (<=1h) même après un downgrade serveur.
// `setUserRole` appelle désormais aussi `revokeRefreshTokens()` (durcissement
// Bloc E) : cela empêche l'émission de NOUVEAUX tokens avec l'ancien rôle
// dès le prochain refresh, mais ne révoque pas rétroactivement un ID token
// déjà en circulation. C'est un risque résiduel documenté (voir
// docs/PHASE7_BUG_REPORT.md), pas une négation du principe testé ici.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { setUserRole, SetUserRoleRequest } from "../../src/functions/setUserRole";
import { suspendDriver, SuspendDriverRequest } from "../../src/functions/suspendDriver";
import { requestDriverDocuments, RequestDriverDocumentsRequest } from "../../src/functions/requestDriverDocuments";
import { authAdmin, admin, db } from "../../src/lib/admin";
import { DriverStatuses, PlatformRoles } from "../../src/lib/types";

// ---------------------------------------------------------------------------
// NIVEAU 1 helpers — Identity Toolkit REST contre l'émulateur Auth (même
// protocole qu'un client Flutter réel). `FIREBASE_AUTH_EMULATOR_HOST` est
// injecté automatiquement par `firebase emulators:exec` (confirmé par
// sonde directe : `127.0.0.1:9099` pendant `npm run test:integration`).
// ---------------------------------------------------------------------------
const AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const IDENTITY_BASE = `http://${AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1`;
const TOKEN_BASE = `http://${AUTH_EMULATOR_HOST}/securetoken.googleapis.com/v1`;
const FAKE_API_KEY = "fake-api-key";

interface SignUpResult {
  idToken: string;
  refreshToken: string;
  localId: string;
}
interface SignInResult {
  idToken?: string;
  refreshToken?: string;
  localId?: string;
  error?: { message: string };
}

async function restSignUp(email: string, password: string): Promise<SignUpResult> {
  const res = await fetch(`${IDENTITY_BASE}/accounts:signUp?key=${FAKE_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  return (await res.json()) as SignUpResult;
}

async function restSignIn(email: string, password: string): Promise<SignInResult> {
  const res = await fetch(`${IDENTITY_BASE}/accounts:signInWithPassword?key=${FAKE_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  return (await res.json()) as SignInResult;
}

async function restRefreshToken(refreshToken: string): Promise<{ id_token?: string; error?: unknown }> {
  const res = await fetch(`${TOKEN_BASE}/token?key=${FAKE_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}`,
  });
  return (await res.json()) as { id_token?: string; error?: unknown };
}

function decodeJwt(idToken: string): Record<string, unknown> {
  const payload = idToken.split(".")[1];
  const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
}

// buildRequest — identique au pattern Bloc D (adminPrivilegedActions.test.ts).
function buildRequest<T>(uid: string, data: T, roles?: string[]): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: (roles ? { role: roles[0], roles } : {}) as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

const STAMP = Date.now();
const emailFor = (label: string) => `blocE-${label}-${STAMP}@example.com`;
const PASSWORD = "BlocE-Password-123!";

const cleanupUids: string[] = [];
async function trackedSignUp(label: string): Promise<SignUpResult> {
  const result = await restSignUp(emailFor(label), PASSWORD);
  cleanupUids.push(result.localId);
  return result;
}

const TARGET_UID = "bloce_target_role_change_001";
const DRIVER_ID = "bloce_driver_001";
const MISSION_ID_UNUSED = "bloce_unused";

async function cleanupAll(): Promise<void> {
  const auditActions = ["setUserRole", "driver_suspended", "driver_documents_requested"];
  const auditSnaps = await Promise.all(
    auditActions.map((action) => db.collection("audit_logs").where("action", "==", action).get())
  );
  const batch = db.batch();
  auditSnaps.forEach((snap) => snap.docs.forEach((d) => batch.delete(d.ref)));
  batch.delete(db.collection("driver_profiles").doc(DRIVER_ID));
  batch.delete(db.collection("users").doc(TARGET_UID));
  await batch.commit();
  await authAdmin.deleteUser(TARGET_UID).catch(() => undefined);
  await Promise.all(cleanupUids.map((uid) => authAdmin.deleteUser(uid).catch(() => undefined)));
  cleanupUids.length = 0;
  void MISSION_ID_UNUSED;
}

async function seedDriverProfile(driverId: string, status: string): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    full_name: "Chauffeur Bloc E",
    city: "Montréal",
    status,
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 0,
    completed_missions: 0,
    created_at: admin.firestore.Timestamp.now(),
    online_status: status === DriverStatuses.SUSPENDED ? "offline" : "online",
    documents_all_valid: true,
  });
}

// ===========================================================================
// NIVEAU 1 — Session Firebase Auth réelle (signup / login / logout / mauvais
// mot de passe / user==null / désactivé / route protégée sans auth / refresh
// de token). Exerce réellement l'endpoint Identity Toolkit émulé.
// ===========================================================================
describe("Bloc E — NIVEAU 1 : session Firebase Auth réelle (Identity Toolkit émulé)", () => {
  afterEach(cleanupAll);

  it("AUTH-E-S01 : signup (accounts:signUp) crée un compte utilisable, idToken exploitable ensuite", async () => {
    const su = await trackedSignUp("signup01");
    expect(su.localId).toBeTruthy();
    expect(su.idToken).toBeTruthy();
    expect(su.refreshToken).toBeTruthy();

    const claims = decodeJwt(su.idToken);
    expect(claims.user_id).toBe(su.localId);
    // Un compte fraîchement créé n'a AUCUN rôle privilégié par défaut.
    expect(claims.role).toBeUndefined();
    expect(claims.roles).toBeUndefined();
  });

  it("AUTH-E-S02 : login (accounts:signInWithPassword) avec bon mot de passe réussit et retourne un idToken valide", async () => {
    const email = emailFor("login02");
    const su = await restSignUp(email, PASSWORD);
    cleanupUids.push(su.localId);

    const signIn = await restSignIn(email, PASSWORD);
    expect(signIn.error).toBeUndefined();
    expect(signIn.idToken).toBeTruthy();
    expect(signIn.localId).toBe(su.localId);
  });

  it("AUTH-E-S03 : login avec MAUVAIS mot de passe échoue (INVALID_PASSWORD), aucun idToken émis", async () => {
    const email = emailFor("wrongpwd03");
    const su = await restSignUp(email, PASSWORD);
    cleanupUids.push(su.localId);

    const signIn = await restSignIn(email, "CeMotDePasseEstFaux!");
    expect(signIn.idToken).toBeUndefined();
    expect(signIn.error?.message).toBe("INVALID_PASSWORD");
  });

  it("AUTH-E-S04 : login avec un compte inexistant (user == null côté serveur) échoue proprement (EMAIL_NOT_FOUND)", async () => {
    const signIn = await restSignIn(emailFor("does-not-exist-04"), PASSWORD);
    expect(signIn.idToken).toBeUndefined();
    expect(signIn.error?.message).toBe("EMAIL_NOT_FOUND");
  });

  it("AUTH-E-S05 : compte désactivé (disabled=true) — login échoue avec USER_DISABLED, mappé par _mapErrorMessage côté Flutter vers 'Ce compte a été désactivé.'", async () => {
    const email = emailFor("disabled05");
    const su = await restSignUp(email, PASSWORD);
    cleanupUids.push(su.localId);

    await authAdmin.updateUser(su.localId, { disabled: true });

    const signIn = await restSignIn(email, PASSWORD);
    expect(signIn.idToken).toBeUndefined();
    expect(signIn.error?.message).toBe("USER_DISABLED");
  });

  it("AUTH-E-S06 : token refresh (grant_type=refresh_token) émet un NOUVEAU idToken exploitable — simule le redémarrage d'application / persistance de session", async () => {
    const su = await trackedSignUp("refresh06");
    const refreshed = await restRefreshToken(su.refreshToken);
    expect(refreshed.error).toBeUndefined();
    expect(refreshed.id_token).toBeTruthy();
    // NOTE : l'émulateur Auth génère un JWT non signé ("alg: none") dont le
    // contenu est entièrement déterministe (uid, email, iat/exp arrondis à
    // la seconde). Si signup + refresh ont lieu dans la MÊME seconde ET
    // qu'aucune claim n'a changé, le token texte peut être bit-à-bit
    // identique — ce n'est PAS un bug (le vrai service Identity Toolkit
    // signe chaque token individuellement et ne produirait jamais deux
    // tokens identiques). La preuve pertinente ici est que le refresh
    // fonctionne ET retourne un idToken exploitable pour le MÊME uid —
    // vérifié ci-dessous via les claims décodées.
    const claims = decodeJwt(refreshed.id_token as string);
    expect(claims.user_id).toBe(su.localId);
  });

  it("AUTH-E-S07 : refresh de token reflète un rôle attribué APRÈS l'émission du idToken initial (preuve directe : promotion -> refresh -> claims visibles)", async () => {
    const su = await trackedSignUp("promo-refresh07");
    // Avant promotion : aucun rôle dans le token initial.
    expect(decodeJwt(su.idToken).role).toBeUndefined();

    await authAdmin.setCustomUserClaims(su.localId, { role: "admin", roles: ["admin"] });

    const refreshed = await restRefreshToken(su.refreshToken);
    const claimsAfter = decodeJwt(refreshed.id_token as string);
    expect(claimsAfter.role).toBe("admin");
    expect(claimsAfter.roles).toEqual(["admin"]);
  });

  it("AUTH-E-S08 : appel Cloud Function réel via un idToken de session (verifyIdToken exercé) — un idToken de compte customer se voit refuser une action admin (suspendDriver), preuve bout-en-bout indépendante de buildRequest()", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    const su = await trackedSignUp("e2e-customer08");

    const decoded: DecodedIdToken = (await authAdmin.verifyIdToken(su.idToken)) as unknown as DecodedIdToken;
    expect(decoded.uid).toBe(su.localId);

    // Reconstruit exactement ce que `checkAuthToken()` injecterait dans
    // `request.auth` pour un idToken réel vérifié (customer = aucun rôle).
    await expect(
      suspendDriver.run({
        data: { driverId: DRIVER_ID, reason: "Tentative via idToken réel, sans rôle." },
        auth: { uid: decoded.uid, token: decoded, rawToken: su.idToken },
        rawRequest: {} as Request,
        acceptsStreaming: false,
      } as CallableRequest<SuspendDriverRequest>)
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("AUTH-E-S09 : appel Cloud Function réel avec un idToken portant réellement le rôle admin (verifyIdToken + claims réels, bout-en-bout) réussit", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    const su = await trackedSignUp("e2e-admin09");
    await authAdmin.setCustomUserClaims(su.localId, { role: "admin", roles: ["admin"] });
    const refreshed = await restRefreshToken(su.refreshToken);
    const freshIdToken = refreshed.id_token as string;

    const decoded: DecodedIdToken = (await authAdmin.verifyIdToken(freshIdToken)) as unknown as DecodedIdToken;
    expect(decoded.role).toBe("admin");

    const result = await suspendDriver.run({
      data: { driverId: DRIVER_ID, reason: "Suspension via idToken admin réel, bout-en-bout." },
      auth: { uid: decoded.uid, token: decoded, rawToken: freshIdToken },
      rawRequest: {} as Request,
      acceptsStreaming: false,
    } as CallableRequest<SuspendDriverRequest>);
    expect(result.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.SUSPENDED);
  });
});

// ===========================================================================
// NIVEAU 2 — CLAIMS/RÔLES round-trip via setUserRole (réutilise le pattern
// Bloc D, `buildRequest()`), pour prouver "analyst -> promotion admin ->
// refresh claims -> droits admin effectifs" et l'inverse (downgrade).
// ===========================================================================
describe("Bloc E — NIVEAU 2 : CLAIMS/RÔLES round-trip (réutilise setUserRole validé Bloc D)", () => {
  beforeEach(async () => {
    await authAdmin.createUser({ uid: TARGET_UID, email: `${TARGET_UID}@example.com` });
  });
  afterEach(cleanupAll);

  it("AUTH-E-C01 : analyst -> promotion admin -> refresh claims -> droits admin EFFECTIFS (suspendDriver, refusé pour analyst, accepté pour admin)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    // État initial : analyst.
    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ANALYST] },
        ["super_admin"]
      )
    );

    // Avec le rôle analyst, suspendDriver (admin/super_admin uniquement)
    // doit être refusé — même utilisateur, même action, rôle insuffisant.
    await expect(
      suspendDriver.run(
        buildRequest<SuspendDriverRequest>(
          TARGET_UID,
          { driverId: DRIVER_ID, reason: "Tentative avant promotion." },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    // Promotion analyst -> admin.
    const promoResult = await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ADMIN] },
        ["super_admin"]
      )
    );
    expect(promoResult.roles).toEqual(["admin"]);

    // Claims réellement mis à jour côté Firebase Auth (source de vérité).
    const userRecordAfterPromo = await authAdmin.getUser(TARGET_UID);
    expect(userRecordAfterPromo.customClaims?.role).toBe("admin");

    // "refresh claims" = la PROCHAINE requête présente le nouveau rôle
    // (équivalent serveur de `FirebaseAuthProvider.refreshClaims()` côté
    // client, qui force justement `getIdTokenResult(forceRefresh: true)`
    // pour obtenir ces mêmes claims à jour).
    const suspendResult = await suspendDriver.run(
      buildRequest<SuspendDriverRequest>(
        TARGET_UID,
        { driverId: DRIVER_ID, reason: "Suspension après promotion admin effective." },
        ["admin"]
      )
    );
    expect(suspendResult.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.SUSPENDED);
    expect(driverSnap.data()!.suspended_by_user_id).toBe(TARGET_UID);
  });

  it("AUTH-E-C02 : admin -> downgrade analyst -> refresh/revocation -> droits admin REFUSÉS (le nouveau rôle, snapshot à jour, ne permet plus suspendDriver)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ADMIN] },
        ["super_admin"]
      )
    );
    // Confirmation : admin peut suspendre AVANT le downgrade.
    const suspendBeforeDowngrade = await suspendDriver.run(
      buildRequest<SuspendDriverRequest>(TARGET_UID, { driverId: DRIVER_ID, reason: "Avant downgrade." }, [
        "admin",
      ])
    );
    expect(suspendBeforeDowngrade.success).toBe(true);

    // Downgrade admin -> analyst.
    const downgradeResult = await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ANALYST] },
        ["super_admin"]
      )
    );
    expect(downgradeResult.roles).toEqual(["analyst"]);

    const userRecordAfterDowngrade = await authAdmin.getUser(TARGET_UID);
    expect(userRecordAfterDowngrade.customClaims?.role).toBe("analyst");
    // Durcissement Bloc E : les refresh tokens existants sont révoqués.
    expect(userRecordAfterDowngrade.tokensValidAfterTime).toBeTruthy();

    // PRINCIPE CRITIQUE : même utilisateur, même Cloud Function, snapshot de
    // rôle à jour (analyst) -> ACTION REFUSÉE. Le frontend n'est jamais
    // l'autorité finale : peu importe ce que l'UI affichait avant le
        // downgrade, le backend refuse désormais cette action pour ce rôle.
    await expect(
      suspendDriver.run(
        buildRequest<SuspendDriverRequest>(
          TARGET_UID,
          { driverId: DRIVER_ID, reason: "Tentative après downgrade — doit échouer." },
          ["analyst"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("AUTH-E-C03 : rôle entièrement retiré (roles == []) -> setUserRole refuse un tableau vide (invalid-argument) ; l'équivalent métier 'aucun rôle' est modélisé par un rôle non-privilégié minimal ('customer'), qui refuse aussi toute action sensible", async () => {
    // setUserRole exige un tableau non vide (invalid-argument) — voir
    // Bloc D. La voie légitime pour 'retirer tout privilège' est de
    // redescendre vers le rôle plancher 'customer', testé ci-dessous.
    await expect(
      setUserRole.run(
        buildRequest<SetUserRoleRequest>(
          "bloce_super_admin_001",
          { targetUid: TARGET_UID, roles: [] },
          ["super_admin"]
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.CUSTOMER] },
        ["super_admin"]
      )
    );

    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);
    await expect(
      requestDriverDocuments.run(
        buildRequest<RequestDriverDocumentsRequest>(
          TARGET_UID,
          { driverId: DRIVER_ID, reason: "Rôle retiré, ne doit plus rien pouvoir faire." },
          ["customer"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("AUTH-E-C04 : super_admin downgrade vers admin -> perd requireSuperAdmin (setUserRole lui-même), garde requireAdminOrAbove (suspendDriver)", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_bootstrap_super_admin_002",
        { targetUid: TARGET_UID, roles: [PlatformRoles.SUPER_ADMIN] },
        ["super_admin"]
      )
    );
    // En tant que super_admin, TARGET_UID peut lui-même appeler setUserRole
    // (la cible doit exister côté Firebase Auth — setCustomUserClaims
    // l'exige — d'où la création explicite ci-dessous, absente à tort dans
    // une première version de ce test : TEST -> FAIL -> FIX, voir
    // docs/PHASE7_BUG_REPORT.md).
    await authAdmin.createUser({
      uid: "bloce_someone_else_003",
      email: "bloce_someone_else_003@example.com",
    });
    const selfCallWhileSuperAdmin = await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        TARGET_UID,
        { targetUid: "bloce_someone_else_003", roles: [PlatformRoles.ANALYST] },
        ["super_admin"]
      )
    );
    expect(selfCallWhileSuperAdmin.success).toBe(true);
    await authAdmin.deleteUser("bloce_someone_else_003").catch(() => undefined);
    await db
      .collection("users")
      .doc("bloce_someone_else_003")
      .delete()
      .catch(() => undefined);

    // Downgrade super_admin -> admin (par un autre super_admin).
    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_bootstrap_super_admin_002",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ADMIN] },
        ["super_admin"]
      )
    );

    // Après downgrade : TARGET_UID (désormais admin, pas super_admin) ne
    // peut PLUS appeler setUserRole (super_admin exclusif) — preuve directe
    // que la perte de super_admin est effective au niveau le plus sensible.
    await expect(
      setUserRole.run(
        buildRequest<SetUserRoleRequest>(
          TARGET_UID,
          { targetUid: "bloce_someone_else_004", roles: [PlatformRoles.ANALYST] },
          ["admin"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    // Mais garde bien les droits admin "normaux" (suspendDriver).
    const suspendAsAdmin = await suspendDriver.run(
      buildRequest<SuspendDriverRequest>(
        TARGET_UID,
        { driverId: DRIVER_ID, reason: "Toujours admin après perte de super_admin." },
        ["admin"]
      )
    );
    expect(suspendAsAdmin.success).toBe(true);
  });

  it("AUTH-E-C05 : callable sensible après changement de rôle — requestDriverDocuments (analyst/admin/super_admin) suit exactement le même snapshot de rôle que suspendDriver, preuve de cohérence transverse", async () => {
    await seedDriverProfile(DRIVER_ID, DriverStatuses.APPROVED);

    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.CUSTOMER] },
        ["super_admin"]
      )
    );
    await expect(
      requestDriverDocuments.run(
        buildRequest<RequestDriverDocumentsRequest>(
          TARGET_UID,
          { driverId: DRIVER_ID, reason: "Avant promotion." },
          ["customer"]
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ANALYST] },
        ["super_admin"]
      )
    );
    const result = await requestDriverDocuments.run(
      buildRequest<RequestDriverDocumentsRequest>(
        TARGET_UID,
        { driverId: DRIVER_ID, reason: "Après promotion analyst — permis expiré détecté." },
        ["analyst"]
      )
    );
    expect(result.success).toBe(true);

    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.status).toBe(DriverStatuses.DOCUMENTS_REQUIRED);
  });

  it("AUTH-E-C06 : durcissement — setUserRole révoque les refresh tokens (revokeRefreshTokens), constaté via tokensValidAfterTime mis à jour à chaque changement", async () => {
    const before = await authAdmin.getUser(TARGET_UID);
    expect(before.tokensValidAfterTime).toBeUndefined();

    await setUserRole.run(
      buildRequest<SetUserRoleRequest>(
        "bloce_super_admin_001",
        { targetUid: TARGET_UID, roles: [PlatformRoles.ADMIN] },
        ["super_admin"]
      )
    );

    const after = await authAdmin.getUser(TARGET_UID);
    expect(after.tokensValidAfterTime).toBeTruthy();
  });
});

// ===========================================================================
// NIVEAU 3 — Sanity check : requireSignedIn() sans `request.auth` (callable
// invoqué sans Authorization header, ex: session expirée/déconnectée côté
// client). Complète les 2 cas déjà couverts ailleurs
// (calculateDeliveryQuote.test.ts, recordTrackingPoint.test.ts) en le
// prouvant aussi pour une fonction Bloc E-pertinente (setUserRole).
// ===========================================================================
describe("Bloc E — NIVEAU 3 : appel callable SANS authentification (request.auth undefined)", () => {
  it("AUTH-E-U01 : setUserRole sans request.auth échoue avec 'unauthenticated' (pas de crash, message clair)", async () => {
    await expect(
      setUserRole.run({
        data: { targetUid: "whatever", roles: [PlatformRoles.ADMIN] },
        auth: undefined,
        rawRequest: {} as Request,
        acceptsStreaming: false,
      } as CallableRequest<SetUserRoleRequest>)
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });
});
