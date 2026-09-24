import { assertIsolatedFirebaseTests, isFirebaseDataSuite, TestEnvironment } from "../testUtils/emulatorSafety";

const valid = (): TestEnvironment => ({
  GCLOUD_PROJECT: "demo-movik-test",
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
  FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
  FIREBASE_STORAGE_EMULATOR_HOST: "127.0.0.1:9199",
  FIREBASE_CONFIG: JSON.stringify({ projectId: "demo-movik-test" }),
});

describe("Firebase test environment safety", () => {
  test("accepts the explicit loopback/demo configuration without mutating it", () => {
    const env = valid(); const before = { ...env };
    expect(() => assertIsolatedFirebaseTests(env)).not.toThrow();
    expect(env).toEqual(before);
  });
  test.each(["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"])("rejects missing %s", (key) => {
    const env = valid(); delete env[key];
    expect(() => assertIsolatedFirebaseTests(env)).toThrow("TEST_SAFETY");
  });
  test.each(["firestore.googleapis.com:443", "10.0.0.2:8080", "https://127.0.0.1:8080", "localhost:0", "localhost:65536", "localhost:8080/path", "localhost"])("rejects remote or malformed endpoint %s", (host) => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), FIRESTORE_EMULATOR_HOST: host })).toThrow("TEST_SAFETY");
  });
  test.each(["localhost:8080", "[::1]:8080"])("accepts loopback %s", (host) => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), FIRESTORE_EMULATOR_HOST: host })).not.toThrow();
  });
  test.each([undefined, "movik-connect-prod", "", "demo-", "Demo-movik"])("rejects non-demo project %s", (project) => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), GCLOUD_PROJECT: project })).toThrow("TEST_SAFETY");
  });
  test("rejects a conflicting project alias", () => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), GOOGLE_CLOUD_PROJECT: "movik-connect-prod" })).toThrow("TEST_SAFETY");
  });
  test.each(["not-json", "C:/credentials.json", "null", "[]", '{}', '{"projectId":"movik-connect-prod"}'])("rejects conflicting or invalid Firebase config", (config) => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), FIREBASE_CONFIG: config })).toThrow("TEST_SAFETY");
  });
  test.each(["sk_live_fake_do_not_use", "rk_live_fake_do_not_use"])("refuses live Stripe key prefixes without disclosing them", (key) => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), STRIPE_SECRET_KEY: key })).toThrow("live Stripe credentials are forbidden");
  });
  test("allows Stripe test keys in sandbox suites", () => {
    expect(() => assertIsolatedFirebaseTests({ ...valid(), STRIPE_TEST_SECRET_KEY: "sk_test_fake" })).not.toThrow();
  });
  test.each(["C:\\repo\\functions\\test\\integration\\x.test.ts", "/repo/functions/test/sandbox/x.sandbox.test.ts"])("detects data suite %s", (path) => {
    expect(isFirebaseDataSuite(path)).toBe(true);
  });
  test("unit suites do not require an emulator", () => {
    expect(isFirebaseDataSuite("/repo/functions/test/unit/x.test.ts")).toBe(false);
  });
});
