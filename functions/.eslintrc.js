module.exports = {
  root: true,
  env: {
    es2021: true,
    node: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: "module",
    project: ["tsconfig.json"],
  },
  plugins: ["@typescript-eslint"],
  extends: ["eslint:recommended"],
  ignorePatterns: ["lib/**/*", "node_modules/**/*"],
  rules: {
    "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
    "no-console": "off",
    // TypeScript vérifie déjà les références non définies (ex: le namespace
    // ambiant `FirebaseFirestore` fourni par firebase-admin) ; no-undef
    // (règle JS pure) génère de faux positifs sur ces types globaux.
    "no-undef": "off",
  },
};
