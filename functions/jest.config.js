/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src", "<rootDir>/test"],
  testMatch: ["**/*.test.ts"],
  // Les tests unitaires purs (pricingEngine) n'ont PAS besoin de credentials
  // ni d'émulateur — voir test/unit/*. Les tests d'intégration (test/integration/*)
  // nécessitent l'Émulateur Firestore/Auth démarré au préalable (voir package.json
  // script `test:integration`).
  testTimeout: 30000,
};
