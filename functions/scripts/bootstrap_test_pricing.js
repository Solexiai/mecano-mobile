// -----------------------------------------------------------------------------
// bootstrap_test_pricing.js — ONE-SHOT guarded bootstrap for Phase 8 pilot.
//
// Purpose:
// - create the missing immutable pricing_versions/PREPROD-TEST-PRICING-001
// - point pricing_configs/active to that version
// - keep ALL runtime flags untouched (especially payments/payouts)
// - write an append-only audit entry
//
// This is TEST/PREPRODUCTION pricing only. It intentionally reuses the values
// already exercised by functions/test/unit/fixtures.ts. Every supported vehicle
// category receives the same test rule so functional E2E tests are not blocked
// by category selection while launch pricing is still undecided.
//
// SAFETY:
// - hard-pinned to movik-connect-prod
// - refuses to overwrite an existing active pricing pointer
// - refuses to overwrite an existing pricing version
// - does not modify system_config/runtime_flags
// - no service-account JSON; uses the existing Firebase CLI OAuth session
//
// Run from the functions directory after `firebase login`:
//   node scripts/bootstrap_test_pricing.js
// -----------------------------------------------------------------------------

const fs = require("fs");
const os = require("os");
const path = require("path");
const { OAuth2Client } = require("google-auth-library");
const { Firestore, FieldValue } = require("@google-cloud/firestore");

const PROJECT_ID = "movik-connect-prod";
const VERSION_ID = "PREPROD-TEST-PRICING-001";

const VEHICLE_CATEGORIES = [
  "car",
  "suv",
  "minivan",
  "cargo_van",
  "pickup_truck",
  "cube_truck",
  "truck",
  "trailer",
  "suv_with_trailer",
  "small_commercial",
  "other",
];

function loadCliSession() {
  const configPath = path.join(
    os.homedir(),
    ".config",
    "configstore",
    "firebase-tools.json",
  );
  const raw = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const tokens = raw.tokens;
  if (!tokens || !tokens.refresh_token) {
    throw new Error(
      "Aucune session Firebase CLI valide. Exécutez `firebase login` puis relancez le script.",
    );
  }
  return {
    refreshToken: tokens.refresh_token,
    operatorEmail: raw.user?.email || null,
  };
}

function buildTestPricing() {
  return {
    pricing_version: VERSION_ID,
    is_active: true,
    effective_from: FieldValue.serverTimestamp(),
    vehicle_rules: VEHICLE_CATEGORIES.map((category) => ({
      category,
      base_fare: 20,
      rate_per_km: 1.5,
      rate_per_minute: 0.3,
      minimum_charge: 25,
    })),
    handling_fees: {
      loading_fee: 0,
      unloading_fee: 0,
      heavy_item_fee: 10,
      bulky_item_fee: 0,
      stairs_fee: 0,
      no_elevator_fee: 0,
      second_handler_fee: 0,
      special_equipment_fee: 0,
    },
    waiting_fee: {
      free_waiting_minutes: 10,
      waiting_rate_per_minute: 0.5,
    },
    additional_stop_fee: {
      fee_per_stop: 5,
    },
    surcharges: [],
    customer_service_fee: {
      service_fee_rate: 0,
      minimum_service_fee: 0,
    },
    commission: {
      standard_commission_rate: 0.15,
      minimum_platform_commission: 0,
      maximum_effective_commission_rate: 1.0,
    },
    tip_policy: {
      driver_tip_percentage: 100,
    },
    quote_config: {
      quote_validity_minutes: 15,
    },
    tax_rate: 0,
    configuration_scope: "preproduction_test_only",
  };
}

async function main() {
  const session = loadCliSession();

  // Public OAuth client used by firebase-tools itself. This is not a private
  // service-account credential; authorization still comes from the operator's
  // local Firebase CLI session and IAM permissions.
  const CLI_CLIENT_ID =
    "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
  const CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";

  const oauth2Client = new OAuth2Client(CLI_CLIENT_ID, CLI_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: session.refreshToken });

  const firestore = new Firestore({
    projectId: PROJECT_ID,
    authClient: oauth2Client,
  });

  const activeRef = firestore.collection("pricing_configs").doc("active");
  const versionRef = firestore.collection("pricing_versions").doc(VERSION_ID);
  const runtimeFlagsRef = firestore.collection("system_config").doc("runtime_flags");
  const auditRef = firestore.collection("audit_logs").doc();

  console.log(`Projet Firebase : ${PROJECT_ID}`);
  console.log(`Version TEST    : ${VERSION_ID}`);
  console.log(`Opérateur       : ${session.operatorEmail || "inconnu"}`);

  const runtimeSnap = await runtimeFlagsRef.get();
  if (runtimeSnap.exists) {
    const flags = runtimeSnap.data() || {};
    console.log("Runtime flags (lecture seulement) :", {
      accept_new_delivery_requests: flags.accept_new_delivery_requests,
      allow_driver_acceptance: flags.allow_driver_acceptance,
      payments_enabled: flags.payments_enabled,
      driver_payouts_enabled: flags.driver_payouts_enabled,
    });
  } else {
    console.log(
      "⚠ system_config/runtime_flags absent — le script ne le crée ni ne le modifie.",
    );
  }

  await firestore.runTransaction(async (tx) => {
    const [activeSnap, versionSnap] = await Promise.all([
      tx.get(activeRef),
      tx.get(versionRef),
    ]);

    if (activeSnap.exists) {
      const current = activeSnap.data()?.active_pricing_version || "(inconnue)";
      throw new Error(
        `ABORT: pricing_configs/active existe déjà et pointe vers ${current}. Aucune donnée n'a été écrasée.`,
      );
    }

    if (versionSnap.exists) {
      throw new Error(
        `ABORT: pricing_versions/${VERSION_ID} existe déjà. Les versions tarifaires sont immuables.`,
      );
    }

    const operatorId = session.operatorEmail
      ? `local_cli:${session.operatorEmail}`
      : "local_cli:unknown";

    tx.set(versionRef, buildTestPricing());
    tx.set(activeRef, {
      active_pricing_version: VERSION_ID,
      updated_at: FieldValue.serverTimestamp(),
      updated_by_user_id: operatorId,
      configuration_scope: "preproduction_test_only",
    });
    tx.set(auditRef, {
      id: auditRef.id,
      actor_user_id: operatorId,
      actor_role: "bootstrap_operator",
      action: "bootstrap_preproduction_test_pricing",
      source_function: "bootstrap_test_pricing.js",
      target_id: VERSION_ID,
      metadata: {
        vehicle_rule_count: VEHICLE_CATEGORIES.length,
        pricing_source: "functions/test/unit/fixtures.ts",
        payments_flags_modified: false,
      },
      created_at: FieldValue.serverTimestamp(),
    });
  });

  const [activeVerify, versionVerify] = await Promise.all([
    activeRef.get(),
    versionRef.get(),
  ]);

  const activeVersion = activeVerify.data()?.active_pricing_version;
  if (!activeVerify.exists || !versionVerify.exists || activeVersion !== VERSION_ID) {
    throw new Error("Vérification post-écriture échouée.");
  }

  console.log("\n✅ Configuration tarifaire TEST créée et vérifiée.");
  console.log(`pricing_configs/active -> ${VERSION_ID}`);
  console.log(`pricing_versions/${VERSION_ID} -> ${VEHICLE_CATEGORIES.length} catégories`);
  console.log("✅ Aucun runtime flag n'a été modifié.");
  console.log("✅ Aucun paiement ou payout n'a été activé.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("\n❌ Bootstrap pricing annulé :", err.message || err);
    process.exit(1);
  });
