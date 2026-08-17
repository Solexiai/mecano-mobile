// -----------------------------------------------------------------------------
// cleanup_e2e_test_driver.js — Supprime les documents Firestore résiduels
// d'un compte de test E2E (users/{uid}, driver_profiles/{uid}) qui NE
// PEUVENT PAS être supprimés côté client (firestore.rules impose
// `allow delete: if false` inconditionnel sur ces deux collections — aucune
// Cloud Function de suppression n'existe non plus, par design : en
// production, on ne supprime jamais un profil chauffeur, on le suspend/rejette).
//
// Utilise les credentials OAuth de la session `firebase login` locale
// (même mécanisme que scripts/bootstrap_super_admins.js) — PAS de clé Admin
// SDK, PAS de service account. Le compte OAuth humain doit avoir les
// permissions IAM Firestore sur le projet (c'est le cas pour
// dantang3030@gmail.com, propriétaire du projet).
//
// USAGE : node scripts/cleanup_e2e_test_driver.js <uid>
// -----------------------------------------------------------------------------

const fs = require("fs");
const os = require("os");
const path = require("path");
const { OAuth2Client } = require("google-auth-library");

const PROJECT_ID = "movik-connect-prod";

function loadCliCredentials() {
  const configPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  const raw = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const tokens = raw.tokens;
  if (!tokens || !tokens.refresh_token) {
    throw new Error("Aucun refresh_token trouvé dans la session `firebase login`.");
  }
  return tokens;
}

async function main() {
  const uid = process.argv[2];
  if (!uid) {
    console.error("Usage: node scripts/cleanup_e2e_test_driver.js <uid>");
    process.exit(1);
  }

  const tokens = loadCliCredentials();
  const CLI_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
  const CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"; // public, voir bootstrap_super_admins.js
  const oauth2Client = new OAuth2Client(CLI_CLIENT_ID, CLI_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: tokens.refresh_token });

  const { Firestore } = require("@google-cloud/firestore");
  const firestoreClient = new Firestore({ projectId: PROJECT_ID, authClient: oauth2Client });

  const collections = ["users", "driver_profiles"];
  for (const col of collections) {
    const ref = firestoreClient.collection(col).doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`⏭  ${col}/${uid} n'existe pas (déjà nettoyé ou jamais créé).`);
      continue;
    }
    await ref.delete();
    console.log(`🗑  ${col}/${uid} supprimé.`);
  }

  console.log(`\n✅ Nettoyage terminé pour uid=${uid}.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Erreur lors du nettoyage:", err);
    process.exit(1);
  });
