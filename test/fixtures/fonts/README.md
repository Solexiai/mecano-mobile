# Public widget test fonts

These unmodified Roboto fixtures were copied from the already installed Flutter SDK material_fonts cache used for the validated Windows widget tests on 2026-10-14. They are test-only assets, not application assets. The original Apache 2.0 license is retained in roboto_license.txt.

Fresh Linux SDK installations used in PR #52 did not contain these Roboto files. Versioning the four existing weights makes truncation and layout checks reproducible without downloading fonts during tests or replacing assertions with Ahem metrics. MaterialIcons continues to come from the pinned Flutter SDK. Widget rendering does not certify Chrome font rendering.
