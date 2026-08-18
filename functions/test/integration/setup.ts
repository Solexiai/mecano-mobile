// ---------------------------------------------------------------------------
// Setup partagé pour les tests d'intégration Firebase Emulator Suite
// (Security Rules + transactions Firestore).
//
// IMPORTANT : ces tests nécessitent que les émulateurs Firestore/Auth soient
// déjà démarrés (voir package.json script "test:integration" qui utilise
// `firebase emulators:exec`). Ils ne doivent JAMAIS être exécutés contre un
// projet Firebase réel — le projectId utilisé est un "demo-*" project ID,
// garanti par firebase-tools de ne jamais atteindre de service non-émulé.
// ---------------------------------------------------------------------------

import * as fs from "fs";
import * as path from "path";
import { initializeTestEnvironment, RulesTestEnvironment } from "@firebase/rules-unit-testing";

export const PROJECT_ID = "demo-movik-test";

export async function createTestEnv(): Promise<RulesTestEnvironment> {
  const rulesPath = path.resolve(__dirname, "../../../firestore.rules");
  const rules = fs.readFileSync(rulesPath, "utf8");

  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });
}

// Variante incluant l'émulateur Storage (utilisée par storageRules.test.ts).
// Les règles Storage référencent Firestore (`firestore.get(...)`) pour
// vérifier la propriété d'une mission — les DEUX émulateurs doivent donc
// être actifs simultanément (voir package.json script "test:integration"
// qui démarre déjà firestore + auth + storage).
export async function createTestEnvWithStorage(): Promise<RulesTestEnvironment> {
  const firestoreRulesPath = path.resolve(__dirname, "../../../firestore.rules");
  const firestoreRules = fs.readFileSync(firestoreRulesPath, "utf8");
  const storageRulesPath = path.resolve(__dirname, "../../../storage.rules");
  const storageRules = fs.readFileSync(storageRulesPath, "utf8");

  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: firestoreRules,
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: storageRules,
      host: "127.0.0.1",
      port: 9199,
    },
  });
}
