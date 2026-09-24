// FIRST setupFilesAfterEnv entry in both Jest configurations.
// Runs before suite imports can initialize Firebase Admin or issue writes.
import { assertIsolatedFirebaseTests, isFirebaseDataSuite } from "./testUtils/emulatorSafety";

if (isFirebaseDataSuite(expect.getState().testPath ?? "")) {
  assertIsolatedFirebaseTests(process.env);
} else {
  // Unit tests must mock external I/O. An accidental SDK call must never fall
  // back to local ADC / a real project, even after a future refactor.
  process.env.GCLOUD_PROJECT = "demo-movik-unit";
  process.env.GOOGLE_CLOUD_PROJECT = "demo-movik-unit";
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: "demo-movik-unit" });
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:1";
  process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:1";
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:1";
}

// Direct Jest invocation does not run Firebase CLI parameter resolution.
// Reuse exactly the production declaration defaults, never a permissive quota.
const { ROUTING_QUOTA_DEFAULTS } = jest.requireActual<typeof import("../src/lib/appConfig")>("../src/lib/appConfig");
process.env.ROUTING_REQUESTS_PER_WINDOW ??= String(ROUTING_QUOTA_DEFAULTS.requests);
process.env.ROUTING_WINDOW_SECONDS ??= String(ROUTING_QUOTA_DEFAULTS.windowSeconds);
