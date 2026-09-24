// Single fail-closed boundary for integration and Stripe-sandbox suites.
// Pure validation: no SDK imports, credentials, network calls or mutations.
export type TestEnvironment = Record<string, string | undefined>;

const EMULATOR_HOSTS = [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_AUTH_EMULATOR_HOST",
  "FIREBASE_STORAGE_EMULATOR_HOST",
] as const;

function requireLoopbackEndpoint(name: string, value: string | undefined): void {
  const match = /^(?:127\.0\.0\.1|localhost|\[::1\]):([0-9]{1,5})$/.exec(value ?? "");
  if (!match || Number(match[1]) < 1 || Number(match[1]) > 65535) {
    throw new Error(`TEST_SAFETY: ${name} must target a loopback emulator with a valid port.`);
  }
}

export function assertIsolatedFirebaseTests(env: TestEnvironment): void {
  for (const name of EMULATOR_HOSTS) requireLoopbackEndpoint(name, env[name]);
  const project = env.GCLOUD_PROJECT;
  if (!project || !/^demo-[a-z0-9][a-z0-9-]*$/.test(project)) {
    throw new Error("TEST_SAFETY: GCLOUD_PROJECT must be an explicit demo-* project.");
  }
  if (env.GOOGLE_CLOUD_PROJECT && env.GOOGLE_CLOUD_PROJECT !== project) {
    throw new Error("TEST_SAFETY: conflicting Google Cloud project identifiers.");
  }
  if (env.FIREBASE_CONFIG) {
    let config: { projectId?: unknown };
    try { config = JSON.parse(env.FIREBASE_CONFIG) as { projectId?: unknown }; }
    catch { throw new Error("TEST_SAFETY: FIREBASE_CONFIG must be inline JSON, never a credential file."); }
    if (!config || typeof config !== "object" || config.projectId !== project) {
      throw new Error("TEST_SAFETY: FIREBASE_CONFIG must match the demo project.");
    }
  }
  for (const key of ["STRIPE_SECRET_KEY", "STRIPE_TEST_SECRET_KEY"]) {
    if (/^(?:sk|rk)_live_/.test(env[key] ?? "")) {
      throw new Error("TEST_SAFETY: live Stripe credentials are forbidden in Firebase tests.");
    }
  }
}

export function isFirebaseDataSuite(testPath: string): boolean {
  return /(?:^|\/)test\/(?:integration|sandbox)\//.test(testPath.replace(/\\/g, "/"));
}
