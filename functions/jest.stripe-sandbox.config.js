/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src", "<rootDir>/test/sandbox"],
  testMatch: ["**/*.sandbox.test.ts"],
  setupFilesAfterEnv: ["<rootDir>/test/setupSafety.ts", "<rootDir>/test/setupRouteMock.ts"],
  testTimeout: 120000,
};
