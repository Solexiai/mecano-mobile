/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src", "<rootDir>/test"],
  testMatch: ["**/*.test.ts"],
  setupFilesAfterEnv: ["<rootDir>/test/setupSafety.ts", "<rootDir>/test/setupRouteMock.ts"],
  // Les tests unitaires purs (pricingEngine) n'ont PAS besoin de credentials
  // ni d'émulateur — voir test/unit/*. Les tests d'intégration (test/integration/*)
  // nécessitent l'Émulateur Firestore/Auth démarré au préalable (voir package.json
  // script `test:integration`).
  testTimeout: 30000,
  // In GitHub Actions, failures are also emitted as annotations (readable via
  // the Checks API when raw logs cannot be downloaded). Locally unchanged.
  reporters: process.env.GITHUB_ACTIONS === "true"
    ? ["default", ["github-actions", { silent: false }], "summary"]
    : ["default"],
};
