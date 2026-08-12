// -----------------------------------------------------------------------------
// bootstrap_super_admins.js — Script ONE-SHOT pour attribuer le rôle
// super_admin aux tout premiers comptes, avant que `setUserRole` (qui exige
// déjà un super_admin appelant) ne puisse être utilisé normalement.
//
// SÉCURITÉ :
// - Aucune clé privée de compte de service (Admin SDK JSON) n'est utilisée.
// - Ce script utilise les credentials OAuth de la session CLI locale
//   (celle créée par `firebase login`), via google-auth-library, exactement
//   comme le fait la Firebase CLI elle-même pour ses propres appels API.
// - Ces credentials sont liées au compte Google humain qui a exécuté
//   `firebase login` (dantang3030@gmail.com) et à ses permissions IAM sur le
//   projet — ce n'est PAS un compte de service, donc aucun risque de fuite
//   de clé Admin SDK long-lived.
// - Ce script est destiné à être exécuté UNE SEULE FOIS pour le bootstrap
//   initial. Toute modification de rôle ultérieure DOIT passer par la
//   Cloud Function `setUserRole` (protégée par vérification super_admin).
//
// USAGE :
//   node scripts/bootstrap_super_admins.js
// -----------------------------------------------------------------------------

const fs = require("fs");
const os = require("os");
const path = require("path");
const { GoogleAuth } = require("google-auth-library");
const admin = require("firebase-admin");

const PROJECT_ID = "movik-connect-prod";

// Comptes à bootstrapper en super_admin (email -> uid, fournis par l'utilisateur
// après création manuelle dans Firebase Console > Authentication > Users).
const TARGETS = [
  { email: "dantang3030@gmail.com", uid: "DrnCrQZcBvZHRE9SdsgEeQo8OfM2" },
  { email: "stanguay24@hotmail.com", uid: "whCF0OPpJoaRyzXZLabiwrh5kOH2" },
];

function loadCliCredentials() {
  const configPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  const raw = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const tokens = raw.tokens;
  if (!tokens || !tokens.refresh_token) {
    throw new Error(
      "Aucun refresh_token trouvé dans la session `firebase login`. Relancez `firebase login --no-localhost` d'abord.",
    );
  }
  return tokens;
}

async function main() {
  const tokens = loadCliCredentials();

  // Client OAuth public de la Firebase CLI (identique à celui utilisé par
  // firebase-tools lui-même — voir lib/api.js du package firebase-tools).
  // Ce n'est PAS un secret applicatif : il est déjà public dans le code
  // source open-source de firebase-tools.
  const CLI_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
  const CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";

  const { OAuth2Client } = require("google-auth-library");
  const oauth2Client = new OAuth2Client(CLI_CLIENT_ID, CLI_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: tokens.refresh_token });

  // firebase-admin exige strictement une instance ServiceAccountCredential ou
  // ApplicationDefault pour son wrapper Firestore (vérification `instanceof`
  // interne) — un credential OAuth utilisateur ad-hoc ne passe pas cette
  // vérification. On utilise donc `admin.auth()` (qui accepte un credential
  // custom via getAccessToken) pour les Custom Claims, ET la bibliothèque
  // `@google-cloud/firestore` DIRECTEMENT (elle accepte nativement un
  // `authClient` google-auth-library arbitraire) pour le mirror Firestore.
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

  for (const target of TARGETS) {
    console.log(`\n--- Traitement de ${target.email} (uid=${target.uid}) ---`);

    // Vérification que l'utilisateur existe bien et correspond à l'email attendu.
    const userRecord = await authAdmin.getUser(target.uid);
    if (userRecord.email !== target.email) {
      throw new Error(
        `MISMATCH: uid ${target.uid} correspond à l'email ${userRecord.email}, pas ${target.email}. Abandon par sécurité.`,
      );
    }

    await authAdmin.setCustomUserClaims(target.uid, {
      role: "super_admin",
      roles: ["super_admin"],
    });

    // Mirror Firestore (display-only, jamais utilisé pour l'autorisation réelle
    // — voir setUserRole.ts pour le même pattern).
    await firestoreClient.collection("users").doc(target.uid).set(
      {
        email: target.email,
        roles: ["super_admin"],
        role: "super_admin",
        updated_at: FieldValue.serverTimestamp(),
        bootstrapped_by: "bootstrap_super_admins.js",
      },
      { merge: true },
    );

    console.log(`✔ ${target.email} => super_admin (Custom Claims + mirror Firestore)`);
  }

  console.log("\n✅ Bootstrap terminé. Les comptes doivent se reconnecter (ou appeler");
  console.log("   getIdTokenResult(forceRefresh: true)) pour que le nouveau claim soit visible.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("\n❌ Erreur lors du bootstrap :", err);
    process.exit(1);
  });
