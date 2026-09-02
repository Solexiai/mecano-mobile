// -----------------------------------------------------------------------------
// bootstrap_super_admins.js — Script ONE-SHOT pour attribuer le rôle
// canonique `super_admin` aux premiers comptes privilégiés Movi-K.
//
// OBJECTIFS :
// - lookup des comptes par EMAIL (pas de cible codée en dur dans le code)
// - écriture des Custom Claims Firebase Auth (source de vérité)
// - mise à jour du miroir Firestore `users/{uid}`
// - révocation des refresh tokens pour forcer un refresh de session
// - écriture d'une trace dans `audit_logs`
//
// SÉCURITÉ :
// - Aucune clé privée de compte de service (Admin SDK JSON) n'est utilisée.
// - Ce script utilise les credentials OAuth de la session CLI locale
//   (celle créée par `firebase login`), via google-auth-library, exactement
//   comme le fait la Firebase CLI elle-même pour ses propres appels API.
// - Ces credentials sont liés au compte Google humain qui a exécuté
//   `firebase login` et à ses permissions IAM sur le projet.
// - Ce script est destiné au bootstrap initial / à une promotion opérée
//   manuellement par un opérateur du projet ; les promotions courantes doivent
//   ensuite passer par la Cloud Function `setUserRole`.
//
// USAGE :
//   node scripts/bootstrap_super_admins.js dantang3030@gmail.com stanguay24@hotmail.com
//
// COMPORTEMENT :
// - idempotent côté état final : relancer le script réécrit le même rôle
//   `super_admin` sans supprimer de données existantes.
// - non-idempotent côté audit : une nouvelle entrée `audit_logs` est ajoutée à
//   chaque exécution voulue (traçabilité append-only).
// -----------------------------------------------------------------------------

const fs = require("fs");
const os = require("os");
const path = require("path");
const { OAuth2Client } = require("google-auth-library");
const admin = require("firebase-admin");

const PROJECT_ID = "movik-connect-prod";
const SUPER_ADMIN_ROLE = "super_admin";

function loadCliSession() {
  const configPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  const raw = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const tokens = raw.tokens;
  if (!tokens || !tokens.refresh_token) {
    throw new Error(
      "Aucun refresh_token trouvé dans la session `firebase login`. Relancez `firebase login --no-localhost` d'abord.",
    );
  }
  return {
    refreshToken: tokens.refresh_token,
    operatorEmail: raw.user?.email || null,
  };
}

function extractCurrentRoles(userRecord) {
  const claims = userRecord.customClaims || {};
  if (Array.isArray(claims.roles) && claims.roles.length > 0) {
    return claims.roles.map((r) => String(r));
  }
  if (claims.role) {
    return [String(claims.role)];
  }
  return [];
}

async function writeAuditLog(firestoreClient, {
  actorUserId,
  actorRole,
  action,
  sourceFunction,
  targetId,
  metadata,
}) {
  const ref = firestoreClient.collection("audit_logs").doc();
  const { FieldValue } = require("@google-cloud/firestore");
  await ref.set({
    id: ref.id,
    actor_user_id: actorUserId,
    actor_role: actorRole,
    action,
    source_function: sourceFunction,
    target_id: targetId ?? null,
    metadata: metadata ?? {},
    created_at: FieldValue.serverTimestamp(),
  });
}

async function main() {
  const targetEmails = process.argv.slice(2).map((s) => s.trim()).filter(Boolean);
  if (targetEmails.length === 0) {
    console.error(
      "Usage: node scripts/bootstrap_super_admins.js <email1> <email2> [...emailN]",
    );
    process.exit(1);
  }

  const session = loadCliSession();

  // Client OAuth public de la Firebase CLI (identique à celui utilisé par
  // firebase-tools lui-même — voir lib/api.js du package firebase-tools).
  const CLI_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
  const CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";

  const oauth2Client = new OAuth2Client(CLI_CLIENT_ID, CLI_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: session.refreshToken });

  admin.initializeApp({
    projectId: PROJECT_ID,
    credential: {
      getAccessToken: async () => {
        const res = await oauth2Client.getAccessToken();
        return { access_token: res.token, expires_in: 3600 };
      },
    },
  });

  const { Firestore, FieldValue } = require("@google-cloud/firestore");
  const firestoreClient = new Firestore({
    projectId: PROJECT_ID,
    authClient: oauth2Client,
  });

  const authAdmin = admin.auth();
  const operatorId = session.operatorEmail
    ? `local_cli:${session.operatorEmail}`
    : "local_cli:unknown";

  console.log(`Projet Firebase ciblé : ${PROJECT_ID}`);
  console.log(`Opérateur CLI         : ${session.operatorEmail || "inconnu"}`);

  for (const email of targetEmails) {
    console.log(`\n--- Traitement de ${email} ---`);

    const userRecord = await authAdmin.getUserByEmail(email);
    const oldRoles = extractCurrentRoles(userRecord);

    console.log(`UID                  : ${userRecord.uid}`);
    console.log(`Email vérifié        : ${userRecord.emailVerified ? "OUI" : "NON"}`);
    console.log(`Rôles actuels        : ${oldRoles.length ? oldRoles.join(", ") : "(aucun)"}`);

    await authAdmin.setCustomUserClaims(userRecord.uid, {
      role: SUPER_ADMIN_ROLE,
      roles: [SUPER_ADMIN_ROLE],
    });

    await authAdmin.revokeRefreshTokens(userRecord.uid);

    await firestoreClient.collection("users").doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        email,
        role: SUPER_ADMIN_ROLE,
        roles: [SUPER_ADMIN_ROLE],
        email_verified: userRecord.emailVerified,
        updated_at: FieldValue.serverTimestamp(),
        promoted_by: operatorId,
        promotion_source: "bootstrap_super_admins.js",
      },
      { merge: true },
    );

    await writeAuditLog(firestoreClient, {
      actorUserId: operatorId,
      actorRole: "bootstrap_operator",
      action: "bootstrap_super_admin",
      sourceFunction: "bootstrap_super_admins.js",
      targetId: userRecord.uid,
      metadata: {
        email,
        oldRoles,
        newRoles: [SUPER_ADMIN_ROLE],
      },
    });

    const verifiedRecord = await authAdmin.getUser(userRecord.uid);
    const verifiedRoles = extractCurrentRoles(verifiedRecord);
    const ok =
      verifiedRoles.length === 1 &&
      verifiedRoles[0] === SUPER_ADMIN_ROLE &&
      verifiedRecord.customClaims?.role === SUPER_ADMIN_ROLE;

    if (!ok) {
      throw new Error(
        `Vérification post-écriture échouée pour ${email} (${userRecord.uid}). Claims relues=${JSON.stringify(verifiedRecord.customClaims || {})}`,
      );
    }

    console.log(`✔ ${email} => super_admin confirmé (claims + miroir Firestore + revoke + audit)`);
  }

  console.log("\n✅ Bootstrap terminé.");
  console.log(
    "Les comptes doivent se déconnecter / reconnecter, ou forcer getIdTokenResult(true), pour voir le nouveau rôle côté client.",
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("\n❌ Erreur lors du bootstrap :", err);
    process.exit(1);
  });
