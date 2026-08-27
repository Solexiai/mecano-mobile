// ---------------------------------------------------------------------------
// Tests d'intégration — Firestore Security Rules (Étape 12)
//
// Utilise le Firebase Emulator Suite (@firebase/rules-unit-testing) pour
// exécuter RÉELLEMENT les règles compilées de `firestore.rules` contre des
// contextes authentifiés simulant chaque rôle de la plateforme, et vérifier
// que les Security Rules (pas seulement le code applicatif) bloquent bien
// les écritures interdites.
//
// Scénarios couverts (liste exacte demandée) :
//   - non authentifié
//   - customer / driver / analyst / admin / super_admin
//   - chauffeur suspendu
//   - tentative d'auto-approbation (driver_profiles.status)
//   - tentative de modification de commission (pricing_versions/commission)
//   - tentative de modification de snapshot (financial_snapshots)
//   - tentative d'ajout/modification du ledger (transaction_ledger)
//   - accès croisé (lire les données d'un autre utilisateur)
//   - client modifiant une mission déjà assignée (driver_id)
//   - chauffeur s'auto-assignant une mission sans passer par la Cloud Function
// ---------------------------------------------------------------------------

import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv } from "./setup";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await createTestEnv();
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// -----------------------------------------------------------------------
// users/{userId}
// -----------------------------------------------------------------------
describe("Security Rules — users/{userId}", () => {
  it("un utilisateur NON authentifié ne peut PAS lire un profil utilisateur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/customer_001"), {
        uid: "customer_001",
        roles: ["customer"],
      });
    });

    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "users/customer_001")));
  });

  it("un customer peut lire SON propre profil, mais pas celui d'un autre utilisateur (accès croisé bloqué)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/customer_001"), {
        uid: "customer_001",
        roles: ["customer"],
      });
      await setDoc(doc(ctx.firestore(), "users/customer_002"), {
        uid: "customer_002",
        roles: ["customer"],
      });
    });

    const customer1 = testEnv.authenticatedContext("customer_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(customer1.firestore(), "users/customer_001")));
    // Accès croisé : customer_001 ne doit PAS pouvoir lire le profil de customer_002.
    await assertFails(getDoc(doc(customer1.firestore(), "users/customer_002")));
  });

  it("un analyst PEUT lire le profil de n'importe quel utilisateur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/customer_001"), {
        uid: "customer_001",
        roles: ["customer"],
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "users/customer_001")));
  });

  it("un customer ne peut PAS s'auto-attribuer un rôle plus élevé (roles doit rester inchangé)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/customer_001"), {
        uid: "customer_001",
        roles: ["customer"],
        created_at: 1,
        is_disabled: false,
        email_verified: true,
      });
    });

    const customer1 = testEnv.authenticatedContext("customer_001", { role: "customer" });
    // Tentative d'auto-élévation de privilège : roles -> ['admin'].
    await assertFails(
      updateDoc(doc(customer1.firestore(), "users/customer_001"), {
        uid: "customer_001",
        roles: ["admin"],
        created_at: 1,
        is_disabled: false,
        email_verified: true,
      })
    );
  });
});

// -----------------------------------------------------------------------
// driver_profiles/{driverId} — tentative d'auto-approbation
// -----------------------------------------------------------------------
describe("Security Rules — driver_profiles/{driverId} : auto-approbation interdite", () => {
  it("un chauffeur NE PEUT PAS s'auto-approuver (status -> 'approved') via une écriture cliente directe", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_profiles/driver_001"), {
        uid: "driver_001",
        status: "pending_review",
        approved_at: null,
        approved_by_user_id: null,
        rejection_reason: null,
        identity_verified: false,
        vehicle_verified: false,
        rating: 0,
        completed_missions: 0,
        documents_all_valid: false,
        current_geohash: "",
        online_status: "offline",
      });
    });

    const driver = testEnv.authenticatedContext("driver_001", { role: "driver" });
    await assertFails(
      updateDoc(doc(driver.firestore(), "driver_profiles/driver_001"), {
        status: "approved", // tentative d'auto-approbation
      })
    );
  });

  it("un chauffeur SUSPENDU ne peut pas non plus modifier son propre statut", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_profiles/driver_002"), {
        uid: "driver_002",
        status: "suspended",
        approved_at: null,
        approved_by_user_id: null,
        rejection_reason: null,
        identity_verified: true,
        vehicle_verified: true,
        rating: 4.5,
        completed_missions: 10,
        documents_all_valid: true,
        current_geohash: "",
        online_status: "offline",
      });
    });

    const suspendedDriver = testEnv.authenticatedContext("driver_002", { role: "driver" });
    // Ne peut pas repasser online_status -> 'online' tant que status != 'approved'.
    await assertFails(
      updateDoc(doc(suspendedDriver.firestore(), "driver_profiles/driver_002"), {
        status: "suspended",
        approved_at: null,
        approved_by_user_id: null,
        rejection_reason: null,
        identity_verified: true,
        vehicle_verified: true,
        rating: 4.5,
        completed_missions: 10,
        documents_all_valid: true,
        current_geohash: "",
        online_status: "online",
      })
    );
    // Ni s'auto-réapprouver.
    await assertFails(
      updateDoc(doc(suspendedDriver.firestore(), "driver_profiles/driver_002"), {
        status: "approved",
      })
    );
  });

  it("un chauffeur APPROUVÉ peut passer online_status -> 'online' même si les champs optionnels (documents_required_*/suspended_*/reactivated_*) sont ABSENTS du document (régression réelle détectée par l'E2E analyste : resource.data.X sur un champ absent levait une erreur d'évaluation Security Rules, refusant silencieusement toute mise à jour légitime)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_profiles/driver_online_repro"), {
        uid: "driver_online_repro",
        status: "approved",
        approved_at: "2024-01-01",
        approved_by_user_id: "analyst_x",
        rejection_reason: null,
        identity_verified: false,
        vehicle_verified: false,
        rating: 0,
        completed_missions: 0,
        online_status: "offline",
        // Volontairement ABSENTS (jamais écrits par approveDriver ni par le
        // flux d'onboarding normal) : documents_required_reason/_at/_by_user_id,
        // suspended_at/_by_user_id, suspension_reason, reactivated_at/_by_user_id,
        // documents_all_valid, current_geohash.
      });
    });

    const driver = testEnv.authenticatedContext("driver_online_repro", { role: "driver" });
    await assertSucceeds(
      updateDoc(doc(driver.firestore(), "driver_profiles/driver_online_repro"), {
        online_status: "online",
      })
    );
  });

  it("un customer ne peut PAS lire le profil complet d'un chauffeur qui n'est pas le sien", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_profiles/driver_003"), {
        uid: "driver_003",
        status: "approved",
      });
    });

    const customer = testEnv.authenticatedContext("customer_099", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_profiles/driver_003")));
  });
});

// -----------------------------------------------------------------------
// pricing_versions/{version} — tentative de modification de commission
// -----------------------------------------------------------------------
describe("Security Rules — pricing_versions/{version} : modification de commission interdite", () => {
  it("aucun rôle client (même admin) ne peut écrire directement dans pricing_versions", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "pricing_versions/MOVIK-PRICING-001"), {
        pricing_version: "MOVIK-PRICING-001",
        commission: { standard_commission_rate: 0.15 },
      });
    });

    const admin = testEnv.authenticatedContext("admin_001", { role: "admin" });
    // Tentative de réduire artificiellement la commission plateforme à 0%.
    await assertFails(
      updateDoc(doc(admin.firestore(), "pricing_versions/MOVIK-PRICING-001"), {
        commission: { standard_commission_rate: 0 },
      })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_001", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "pricing_versions/MOVIK-PRICING-001"), {
        commission: { standard_commission_rate: 0 },
      })
    );
  });

  it("tout utilisateur signé PEUT lire pricing_versions (lecture publique, écriture verrouillée)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "pricing_versions/MOVIK-PRICING-001"), {
        pricing_version: "MOVIK-PRICING-001",
      });
    });

    const customer = testEnv.authenticatedContext("customer_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(customer.firestore(), "pricing_versions/MOVIK-PRICING-001")));
  });
});

// -----------------------------------------------------------------------
// financial_snapshots/{id} — IMMUABLE, tentative de modification
// -----------------------------------------------------------------------
describe("Security Rules — financial_snapshots/{id} : immutabilité", () => {
  it("ni le client, ni le chauffeur, ni un admin ne peut modifier un snapshot financier", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "financial_snapshots/snap_001"), {
        snapshot_id: "snap_001",
        customer_id: "customer_001",
        driver_id: "driver_001",
        status: "confirmed",
        driver_net_mission_earnings: 85,
      });
    });

    const customer = testEnv.authenticatedContext("customer_001", { role: "customer" });
    await assertFails(
      updateDoc(doc(customer.firestore(), "financial_snapshots/snap_001"), {
        driver_net_mission_earnings: 999999,
      })
    );

    const driver = testEnv.authenticatedContext("driver_001", { role: "driver" });
    await assertFails(
      updateDoc(doc(driver.firestore(), "financial_snapshots/snap_001"), {
        driver_net_mission_earnings: 999999,
      })
    );

    const admin = testEnv.authenticatedContext("admin_001", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "financial_snapshots/snap_001"), {
        status: "cancelled",
      })
    );

    // Suppression également interdite.
    await assertFails(deleteDoc(doc(admin.firestore(), "financial_snapshots/snap_001")));
  });

  it("le client et le chauffeur concernés peuvent LIRE leur propre snapshot ; un tiers ne peut pas", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "financial_snapshots/snap_002"), {
        snapshot_id: "snap_002",
        customer_id: "customer_001",
        driver_id: "driver_001",
        status: "confirmed",
      });
    });

    const owner = testEnv.authenticatedContext("customer_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "financial_snapshots/snap_002")));

    const stranger = testEnv.authenticatedContext("customer_999", { role: "customer" });
    await assertFails(getDoc(doc(stranger.firestore(), "financial_snapshots/snap_002")));
  });
});

// -----------------------------------------------------------------------
// BLOC J — payments/{id} & refunds/{id} : vérification ciblée (lecture
// propriétaire uniquement, aucune écriture cliente). Couverture minimale
// demandée pour le Bloc J — la couverture EXHAUSTIVE (tous rôles, tous
// champs) reste du ressort du Bloc T.
// -----------------------------------------------------------------------
describe("Security Rules — payments/{paymentId} : lecture propriétaire uniquement (Bloc J)", () => {
  it("le customer propriétaire du paiement peut le lire", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_001"), {
        payment_id: "payment_j_001",
        mission_id: "mission_j_001",
        customer_id: "customer_j_001",
        driver_id: "driver_j_001",
        status: "captured",
      });
    });

    const owner = testEnv.authenticatedContext("customer_j_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "payments/payment_j_001")));
  });

  it("un autre client (non propriétaire) ne peut PAS lire ce paiement", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_002"), {
        payment_id: "payment_j_002",
        mission_id: "mission_j_002",
        customer_id: "customer_j_001",
        driver_id: "driver_j_001",
        status: "captured",
      });
    });

    const stranger = testEnv.authenticatedContext("customer_j_999", { role: "customer" });
    await assertFails(getDoc(doc(stranger.firestore(), "payments/payment_j_002")));
  });

  it("un utilisateur NON authentifié ne peut PAS lire un paiement", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_003"), {
        payment_id: "payment_j_003",
        mission_id: "mission_j_003",
        customer_id: "customer_j_001",
        driver_id: "driver_j_001",
        status: "authorized",
      });
    });

    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "payments/payment_j_003")));
  });

  it("le client propriétaire ne peut PAS écrire/modifier son propre document de paiement", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_004"), {
        payment_id: "payment_j_004",
        mission_id: "mission_j_004",
        customer_id: "customer_j_001",
        driver_id: "driver_j_001",
        status: "authorized",
        amount_captured_minor: 0,
      });
    });

    const owner = testEnv.authenticatedContext("customer_j_001", { role: "customer" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "payments/payment_j_004"), {
        amount_captured_minor: 999999,
      })
    );
  });
});

// -----------------------------------------------------------------------
// driver_payouts/{payoutId} — lecture propriétaire (chauffeur) uniquement
// (Bloc K — UI financière chauffeur, Phase 6).
// -----------------------------------------------------------------------
describe("Security Rules — driver_payouts/{payoutId} : lecture propriétaire (chauffeur) uniquement (Bloc K)", () => {
  it("le chauffeur propriétaire du payout peut le lire", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_001"), {
        payout_id: "payout_k_001",
        driver_id: "driver_k_001",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      });
    });

    const owner = testEnv.authenticatedContext("driver_k_001", { role: "driver" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "driver_payouts/payout_k_001")));
  });

  it("un autre chauffeur (non propriétaire) ne peut PAS lire ce payout", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_002"), {
        payout_id: "payout_k_002",
        driver_id: "driver_k_001",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      });
    });

    const strangerDriver = testEnv.authenticatedContext("driver_k_999", { role: "driver" });
    await assertFails(getDoc(doc(strangerDriver.firestore(), "driver_payouts/payout_k_002")));
  });

  it("un client (customer) ne peut PAS lire un payout chauffeur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_003"), {
        payout_id: "payout_k_003",
        driver_id: "driver_k_001",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      });
    });

    const customer = testEnv.authenticatedContext("customer_k_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_payouts/payout_k_003")));
  });

  it("un utilisateur NON authentifié ne peut PAS lire un payout", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_004"), {
        payout_id: "payout_k_004",
        driver_id: "driver_k_001",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      });
    });

    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "driver_payouts/payout_k_004")));
  });

  it("un analyst PEUT lire n'importe quel payout chauffeur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_005"), {
        payout_id: "payout_k_005",
        driver_id: "driver_k_001",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "driver_payouts/payout_k_005")));
  });

  it("le chauffeur propriétaire ne peut PAS écrire/créer un nouveau payout", async () => {
    const owner = testEnv.authenticatedContext("driver_k_010", { role: "driver" });
    await assertFails(
      setDoc(doc(owner.firestore(), "driver_payouts/payout_k_010"), {
        payout_id: "payout_k_010",
        driver_id: "driver_k_010",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      })
    );
  });

  it("le chauffeur propriétaire ne peut PAS modifier amount_minor sur son propre payout", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_011"), {
        payout_id: "payout_k_011",
        driver_id: "driver_k_011",
        amount_minor: 5000,
        currency: "CAD",
        status: "pending",
      });
    });

    const owner = testEnv.authenticatedContext("driver_k_011", { role: "driver" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "driver_payouts/payout_k_011"), { amount_minor: 999999 })
    );
  });

  it("le chauffeur propriétaire ne peut PAS modifier status sur son propre payout", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_012"), {
        payout_id: "payout_k_012",
        driver_id: "driver_k_012",
        amount_minor: 5000,
        currency: "CAD",
        status: "pending",
      });
    });

    const owner = testEnv.authenticatedContext("driver_k_012", { role: "driver" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "driver_payouts/payout_k_012"), { status: "paid" })
    );
  });

  it("le chauffeur propriétaire ne peut PAS modifier provider_payout_id sur son propre payout", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_013"), {
        payout_id: "payout_k_013",
        driver_id: "driver_k_013",
        amount_minor: 5000,
        currency: "CAD",
        status: "pending",
        provider_payout_id: null,
      });
    });

    const owner = testEnv.authenticatedContext("driver_k_013", { role: "driver" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "driver_payouts/payout_k_013"), {
        provider_payout_id: "po_fake_injected",
      })
    );
  });

  it("le chauffeur propriétaire ne peut PAS supprimer son propre payout", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_payouts/payout_k_014"), {
        payout_id: "payout_k_014",
        driver_id: "driver_k_014",
        amount_minor: 5000,
        currency: "CAD",
        status: "paid",
      });
    });

    const owner = testEnv.authenticatedContext("driver_k_014", { role: "driver" });
    await assertFails(deleteDoc(doc(owner.firestore(), "driver_payouts/payout_k_014")));
  });
});

describe("Security Rules — refunds/{refundId} : lecture propriétaire uniquement (Bloc J)", () => {
  it("le customer propriétaire du paiement lié peut lire le refund", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_010"), {
        payment_id: "payment_j_010",
        mission_id: "mission_j_010",
        customer_id: "customer_j_010",
        driver_id: "driver_j_010",
        status: "refunded",
      });
      await setDoc(doc(ctx.firestore(), "refunds/refund_j_010"), {
        refund_id: "refund_j_010",
        payment_id: "payment_j_010",
        mission_id: "mission_j_010",
        amount_minor: 500,
        status: "succeeded",
      });
    });

    const owner = testEnv.authenticatedContext("customer_j_010", { role: "customer" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "refunds/refund_j_010")));
  });

  it("un autre client (non propriétaire du paiement lié) ne peut PAS lire ce refund", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_011"), {
        payment_id: "payment_j_011",
        mission_id: "mission_j_011",
        customer_id: "customer_j_010",
        driver_id: "driver_j_010",
        status: "refunded",
      });
      await setDoc(doc(ctx.firestore(), "refunds/refund_j_011"), {
        refund_id: "refund_j_011",
        payment_id: "payment_j_011",
        mission_id: "mission_j_011",
        amount_minor: 500,
        status: "succeeded",
      });
    });

    const stranger = testEnv.authenticatedContext("customer_j_999", { role: "customer" });
    await assertFails(getDoc(doc(stranger.firestore(), "refunds/refund_j_011")));
  });

  it("un utilisateur NON authentifié ne peut PAS lire un refund", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_012"), {
        payment_id: "payment_j_012",
        mission_id: "mission_j_012",
        customer_id: "customer_j_010",
        driver_id: "driver_j_010",
        status: "refunded",
      });
      await setDoc(doc(ctx.firestore(), "refunds/refund_j_012"), {
        refund_id: "refund_j_012",
        payment_id: "payment_j_012",
        mission_id: "mission_j_012",
        amount_minor: 500,
        status: "succeeded",
      });
    });

    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "refunds/refund_j_012")));
  });

  it("le client propriétaire ne peut PAS écrire/modifier un refund existant", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "payments/payment_j_013"), {
        payment_id: "payment_j_013",
        mission_id: "mission_j_013",
        customer_id: "customer_j_010",
        driver_id: "driver_j_010",
        status: "refunded",
      });
      await setDoc(doc(ctx.firestore(), "refunds/refund_j_013"), {
        refund_id: "refund_j_013",
        payment_id: "payment_j_013",
        mission_id: "mission_j_013",
        amount_minor: 500,
        status: "succeeded",
      });
    });

    const owner = testEnv.authenticatedContext("customer_j_010", { role: "customer" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "refunds/refund_j_013"), { amount_minor: 999999 })
    );
  });
});

describe("Security Rules — mission_financial_balance/{missionId} : lecture client/chauffeur propriétaires (Bloc J)", () => {
  it("le customer de la mission peut lire son solde financier", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_j_020"), {
        customer_id: "customer_j_020",
        driver_id: "driver_j_020",
        status: "completed",
      });
      await setDoc(doc(ctx.firestore(), "mission_financial_balance/mission_j_020"), {
        mission_id: "mission_j_020",
        customer_charged_minor: 5000,
      });
    });

    const owner = testEnv.authenticatedContext("customer_j_020", { role: "customer" });
    await assertSucceeds(
      getDoc(doc(owner.firestore(), "mission_financial_balance/mission_j_020"))
    );
  });

  it("un tiers sans lien avec la mission ne peut PAS lire ce solde financier", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_j_021"), {
        customer_id: "customer_j_020",
        driver_id: "driver_j_020",
        status: "completed",
      });
      await setDoc(doc(ctx.firestore(), "mission_financial_balance/mission_j_021"), {
        mission_id: "mission_j_021",
        customer_charged_minor: 5000,
      });
    });

    const stranger = testEnv.authenticatedContext("customer_j_999", { role: "customer" });
    await assertFails(
      getDoc(doc(stranger.firestore(), "mission_financial_balance/mission_j_021"))
    );
  });
});

// -----------------------------------------------------------------------
// transaction_ledger/{id} — APPEND-ONLY, tentative d'ajout/modification
// -----------------------------------------------------------------------
describe("Security Rules — transaction_ledger/{id} : append-only, aucune écriture cliente", () => {
  it("aucun rôle (même super_admin) ne peut créer une entrée de ledger directement depuis le client", async () => {
    const superAdmin = testEnv.authenticatedContext("super_admin_001", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "transaction_ledger/ledger_fake_001"), {
        ledger_entry_id: "ledger_fake_001",
        amount: 1000000,
        party: "driver",
        mission_id: "mission_001",
      })
    );
  });

  it("aucun rôle ne peut MODIFIER une entrée de ledger existante (append-only strict)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "transaction_ledger/ledger_001"), {
        ledger_entry_id: "ledger_001",
        amount: 85,
        party: "driver",
        mission_id: "mission_001",
      });
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_001"), {
        customer_id: "customer_001",
        driver_id: "driver_001",
        status: "completed",
      });
    });

    const driver = testEnv.authenticatedContext("driver_001", { role: "driver" });
    // Le chauffeur concerné PEUT lire son entrée...
    await assertSucceeds(getDoc(doc(driver.firestore(), "transaction_ledger/ledger_001")));
    // ...mais ne peut absolument pas la modifier (tenter de gonfler son gain).
    await assertFails(
      updateDoc(doc(driver.firestore(), "transaction_ledger/ledger_001"), { amount: 999999 })
    );
    await assertFails(deleteDoc(doc(driver.firestore(), "transaction_ledger/ledger_001")));

    const admin = testEnv.authenticatedContext("admin_001", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "transaction_ledger/ledger_001"), { amount: 0 })
    );
  });

  it("un tiers sans lien avec la mission ne peut pas lire une entrée de ledger (accès croisé bloqué)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "transaction_ledger/ledger_002"), {
        ledger_entry_id: "ledger_002",
        amount: 85,
        party: "driver",
        mission_id: "mission_002",
      });
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_002"), {
        customer_id: "customer_001",
        driver_id: "driver_001",
        status: "completed",
      });
    });

    const stranger = testEnv.authenticatedContext("driver_999", { role: "driver" });
    await assertFails(getDoc(doc(stranger.firestore(), "transaction_ledger/ledger_002")));
  });
});

// -----------------------------------------------------------------------
// delivery_requests/{missionId} — client modifiant une mission assignée +
// chauffeur s'auto-assignant sans passer par la Cloud Function
// -----------------------------------------------------------------------
describe("Security Rules — delivery_requests/{missionId} : assignation protégée", () => {
  it("un chauffeur NE PEUT PAS s'auto-assigner une mission en écrivant directement driver_id (bypass acceptDelivery)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_010"), {
        customer_id: "customer_001",
        driver_id: null,
        status: "searching_driver",
        driver_offer_amount: 0,
        customer_total: 100,
        payment_status: "pending",
        pricing_version: "MOVIK-PRICING-001",
      });
    });

    const driver = testEnv.authenticatedContext("driver_777", { role: "driver" });
    // Aucune règle 'update' n'autorise un chauffeur à écrire sur
    // delivery_requests : seul le customer_id propriétaire a une règle
    // update, et driver_id est exclusivement Cloud Functions only.
    await assertFails(
      updateDoc(doc(driver.firestore(), "delivery_requests/mission_010"), {
        driver_id: "driver_777",
        status: "assigned",
      })
    );
  });

  it("le client PEUT annuler sa propre mission NON assignée, mais ne peut PAS modifier driver_id/status une fois assignée", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_011"), {
        customer_id: "customer_001",
        driver_id: "driver_555",
        status: "assigned",
        driver_offer_amount: 85,
        customer_total: 100,
        payment_status: "pending",
        pricing_version: "MOVIK-PRICING-001",
      });
    });

    const customer = testEnv.authenticatedContext("customer_001", { role: "customer" });

    // Tentative du client de réassigner la mission à un autre chauffeur (ou
    // de la "libérer" lui-même) : interdit, seule une annulation formelle
    // (status -> 'cancelled') est permise une fois driver_id non-null.
    await assertFails(
      updateDoc(doc(customer.firestore(), "delivery_requests/mission_011"), {
        driver_id: null,
        status: "searching_driver",
      })
    );

    // L'annulation formelle, elle, doit réussir (status -> cancelled,
    // driver_id/driver_offer_amount/customer_total/pricing_version inchangés).
    await assertSucceeds(
      updateDoc(doc(customer.firestore(), "delivery_requests/mission_011"), {
        status: "cancelled",
        cancellation_reason: "changement de plan",
        driver_id: "driver_555",
        driver_offer_amount: 85,
        customer_total: 100,
        pricing_version: "MOVIK-PRICING-001",
      })
    );
  });

  it("un autre client (pas le propriétaire) ne peut PAS lire ni modifier cette mission", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_012"), {
        customer_id: "customer_001",
        driver_id: null,
        status: "searching_driver",
      });
    });

    const otherCustomer = testEnv.authenticatedContext("customer_999", { role: "customer" });
    await assertFails(getDoc(doc(otherCustomer.firestore(), "delivery_requests/mission_012")));
    await assertFails(
      updateDoc(doc(otherCustomer.firestore(), "delivery_requests/mission_012"), {
        status: "cancelled",
      })
    );
  });

  it("un chauffeur approuvé peut voir les missions OUVERTES (searching_driver/offered) même sans y être assigné", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_profiles/driver_888"), {
        uid: "driver_888",
        status: "approved",
      });
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_013"), {
        customer_id: "customer_001",
        driver_id: null,
        status: "searching_driver",
      });
    });

    const approvedDriver = testEnv.authenticatedContext("driver_888", { role: "driver" });
    await assertSucceeds(getDoc(doc(approvedDriver.firestore(), "delivery_requests/mission_013")));
  });

  it("un chauffeur NON approuvé ne peut PAS voir les missions ouvertes", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_profiles/driver_889"), {
        uid: "driver_889",
        status: "pending_review",
      });
      await setDoc(doc(ctx.firestore(), "delivery_requests/mission_014"), {
        customer_id: "customer_001",
        driver_id: null,
        status: "searching_driver",
      });
    });

    const unapprovedDriver = testEnv.authenticatedContext("driver_889", { role: "driver" });
    await assertFails(getDoc(doc(unapprovedDriver.firestore(), "delivery_requests/mission_014")));
  });
});

// -----------------------------------------------------------------------
// driver_documents/{documentId}
// -----------------------------------------------------------------------
describe("Security Rules — driver_documents/{documentId}", () => {
  it("un chauffeur peut créer SON propre document en statut 'uploaded'", async () => {
    const driver = testEnv.authenticatedContext("driver_100", { role: "driver" });
    await assertSucceeds(
      setDoc(doc(driver.firestore(), "driver_documents/doc_100"), {
        driver_id: "driver_100",
        status: "uploaded",
        type: "drivers_license",
      })
    );
  });

  it("un chauffeur ne peut PAS créer un document pour un AUTRE chauffeur (driver_id falsifié)", async () => {
    const driver = testEnv.authenticatedContext("driver_101", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_documents/doc_101"), {
        driver_id: "driver_999",
        status: "uploaded",
        type: "drivers_license",
      })
    );
  });

  it("un chauffeur ne peut PAS créer un document déjà en statut 'approved' (bypass validation)", async () => {
    const driver = testEnv.authenticatedContext("driver_102", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_documents/doc_102"), {
        driver_id: "driver_102",
        status: "approved",
        type: "drivers_license",
      })
    );
  });

  it("un chauffeur NE PEUT PAS changer le status de son document (Cloud Function only : validateDriverDocument)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_103"), {
        driver_id: "driver_103",
        status: "uploaded",
        type: "drivers_license",
      });
    });

    const driver = testEnv.authenticatedContext("driver_103", { role: "driver" });
    await assertFails(
      updateDoc(doc(driver.firestore(), "driver_documents/doc_103"), { status: "approved" })
    );
  });

  it("un analyst NE PEUT PAS non plus modifier directement le status (même règle : Cloud Functions only)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_104"), {
        driver_id: "driver_104",
        status: "uploaded",
        type: "drivers_license",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertFails(
      updateDoc(doc(analyst.firestore(), "driver_documents/doc_104"), { status: "approved" })
    );
  });

  it("le chauffeur propriétaire et un analyst peuvent LIRE le document ; un tiers customer ne peut pas", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_105"), {
        driver_id: "driver_105",
        status: "uploaded",
        type: "drivers_license",
      });
    });

    const owner = testEnv.authenticatedContext("driver_105", { role: "driver" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "driver_documents/doc_105")));

    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "driver_documents/doc_105")));

    const stranger = testEnv.authenticatedContext("customer_999", { role: "customer" });
    await assertFails(getDoc(doc(stranger.firestore(), "driver_documents/doc_105")));
  });

  it("aucun rôle ne peut SUPPRIMER un document chauffeur (immuable, même admin)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_106"), {
        driver_id: "driver_106",
        status: "uploaded",
        type: "drivers_license",
      });
    });

    const admin = testEnv.authenticatedContext("admin_001", { role: "admin" });
    await assertFails(deleteDoc(doc(admin.firestore(), "driver_documents/doc_106")));
  });
});

// -----------------------------------------------------------------------
// driver_vehicles/{vehicleId}
// -----------------------------------------------------------------------
describe("Security Rules — driver_vehicles/{vehicleId}", () => {
  it("un chauffeur peut créer SON propre véhicule avec is_verified: false", async () => {
    const driver = testEnv.authenticatedContext("driver_200", { role: "driver" });
    await assertSucceeds(
      setDoc(doc(driver.firestore(), "driver_vehicles/veh_200"), {
        driver_id: "driver_200",
        is_verified: false,
        plate: "ABC-123",
      })
    );
  });

  it("un chauffeur ne peut PAS créer un véhicule déjà 'is_verified: true' (auto-vérification interdite)", async () => {
    const driver = testEnv.authenticatedContext("driver_201", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_vehicles/veh_201"), {
        driver_id: "driver_201",
        is_verified: true,
        plate: "ABC-124",
      })
    );
  });

  it("le propriétaire peut MODIFIER les infos de son véhicule (ex: plate) mais PAS is_verified", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_202"), {
        driver_id: "driver_202",
        is_verified: false,
        plate: "OLD-000",
      });
    });

    const owner = testEnv.authenticatedContext("driver_202", { role: "driver" });
    // Modification d'un champ non protégé : autorisée.
    await assertSucceeds(
      updateDoc(doc(owner.firestore(), "driver_vehicles/veh_202"), {
        driver_id: "driver_202",
        is_verified: false,
        plate: "NEW-999",
      })
    );
    // Tentative de s'auto-vérifier le véhicule : interdite.
    await assertFails(
      updateDoc(doc(owner.firestore(), "driver_vehicles/veh_202"), {
        driver_id: "driver_202",
        is_verified: true,
        plate: "NEW-999",
      })
    );
  });

  it("un analyst PEUT modifier (ex: vérifier) le véhicule d'un chauffeur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_203"), {
        driver_id: "driver_203",
        is_verified: false,
        plate: "XYZ-000",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertSucceeds(
      updateDoc(doc(analyst.firestore(), "driver_vehicles/veh_203"), { is_verified: true })
    );
  });

  it("un tiers chauffeur ne peut ni lire, ni modifier, ni supprimer le véhicule d'un autre chauffeur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_204"), {
        driver_id: "driver_204",
        is_verified: true,
        plate: "AAA-111",
      });
    });

    const stranger = testEnv.authenticatedContext("driver_999", { role: "driver" });
    await assertFails(getDoc(doc(stranger.firestore(), "driver_vehicles/veh_204")));
    await assertFails(
      updateDoc(doc(stranger.firestore(), "driver_vehicles/veh_204"), { plate: "HACKED" })
    );
    await assertFails(deleteDoc(doc(stranger.firestore(), "driver_vehicles/veh_204")));
  });

  it("le propriétaire PEUT supprimer son propre véhicule", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_205"), {
        driver_id: "driver_205",
        is_verified: false,
        plate: "BBB-222",
      });
    });

    const owner = testEnv.authenticatedContext("driver_205", { role: "driver" });
    await assertSucceeds(deleteDoc(doc(owner.firestore(), "driver_vehicles/veh_205")));
  });
});

// -----------------------------------------------------------------------
// driver_internal_notes/{noteId} — Cloud Functions only (addDriverInternalNote)
// -----------------------------------------------------------------------
describe("Security Rules — driver_internal_notes/{noteId}", () => {
  it("un analyst PEUT lire les notes internes d'un chauffeur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_001"), {
        driver_id: "driver_300",
        author_user_id: "analyst_001",
        author_role: "analyst",
        text: "Permis vérifié en personne.",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "driver_internal_notes/note_001")));
  });

  it("le chauffeur CONCERNÉ par la note NE PEUT PAS la lire (confidentialité analyste stricte)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_002"), {
        driver_id: "driver_301",
        author_user_id: "analyst_001",
        author_role: "analyst",
        text: "Comportement suspect signalé par un client.",
      });
    });

    const concernedDriver = testEnv.authenticatedContext("driver_301", { role: "driver" });
    await assertFails(getDoc(doc(concernedDriver.firestore(), "driver_internal_notes/note_002")));
  });

  it("un customer ne peut évidemment pas lire une note interne", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_003"), {
        driver_id: "driver_302",
        author_user_id: "analyst_001",
        author_role: "analyst",
        text: "Note test.",
      });
    });

    const customer = testEnv.authenticatedContext("customer_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_internal_notes/note_003")));
  });

  it("aucun rôle, même analyst/admin/super_admin, ne peut créer une note directement depuis le client (Cloud Function only)", async () => {
    const analyst = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertFails(
      setDoc(doc(analyst.firestore(), "driver_internal_notes/note_fake_001"), {
        driver_id: "driver_303",
        author_user_id: "analyst_001",
        author_role: "analyst",
        text: "Tentative de bypass de addDriverInternalNote.",
      })
    );

    const admin = testEnv.authenticatedContext("admin_001", { role: "admin" });
    await assertFails(
      setDoc(doc(admin.firestore(), "driver_internal_notes/note_fake_002"), {
        driver_id: "driver_303",
        author_user_id: "admin_001",
        author_role: "admin",
        text: "Tentative de bypass.",
      })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_001", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "driver_internal_notes/note_fake_003"), {
        driver_id: "driver_303",
        author_user_id: "super_admin_001",
        author_role: "super_admin",
        text: "Tentative de bypass.",
      })
    );
  });

  it("aucun rôle ne peut MODIFIER ou SUPPRIMER une note existante (immuable, même l'auteur)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_004"), {
        driver_id: "driver_304",
        author_user_id: "analyst_001",
        author_role: "analyst",
        text: "Note originale.",
      });
    });

    const author = testEnv.authenticatedContext("analyst_001", { role: "analyst" });
    await assertFails(
      updateDoc(doc(author.firestore(), "driver_internal_notes/note_004"), {
        text: "Note modifiée après coup.",
      })
    );
    await assertFails(deleteDoc(doc(author.firestore(), "driver_internal_notes/note_004")));

    const superAdmin = testEnv.authenticatedContext("super_admin_001", { role: "super_admin" });
    await assertFails(deleteDoc(doc(superAdmin.firestore(), "driver_internal_notes/note_004")));
  });
});

// -----------------------------------------------------------------------
// promo_codes/{code} — nouvelle collection Étape 12
// -----------------------------------------------------------------------
describe("Security Rules — promo_codes/{code}", () => {
  it("un utilisateur signé peut LIRE un code promo, mais jamais l'écrire", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "promo_codes/WELCOME10"), {
        code: "WELCOME10",
        discount_mode: "percentage",
        discount_value: 0.1,
        is_active: true,
      });
    });

    const customer = testEnv.authenticatedContext("customer_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(customer.firestore(), "promo_codes/WELCOME10")));
    await assertFails(
      updateDoc(doc(customer.firestore(), "promo_codes/WELCOME10"), { discount_value: 0.99 })
    );

    const admin = testEnv.authenticatedContext("admin_001", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "promo_codes/WELCOME10"), { discount_value: 0.99 })
    );
  });

  it("un utilisateur NON authentifié ne peut pas lire un code promo", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "promo_codes/WELCOME10"), { code: "WELCOME10" });
    });

    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "promo_codes/WELCOME10")));
  });
});

// -----------------------------------------------------------------------
// driver_documents/{documentId} — upload chauffeur, validation Cloud Function only
// -----------------------------------------------------------------------
describe("Security Rules — driver_documents/{documentId}", () => {
  it("un chauffeur peut créer SON document en statut 'uploaded'", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_001", { role: "driver" });
    await assertSucceeds(
      setDoc(doc(driver.firestore(), "driver_documents/doc_001"), {
        driver_id: "driver_doc_001",
        type: "drivers_licence",
        status: "uploaded",
      })
    );
  });

  it("un chauffeur ne peut PAS créer un document avec un statut différent de 'uploaded' (ex: 'approved')", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_documents/doc_002"), {
        driver_id: "driver_doc_002",
        type: "insurance",
        status: "approved", // tentative d'auto-validation
      })
    );
  });

  it("un chauffeur ne peut PAS créer un document pour un AUTRE chauffeur", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_003", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_documents/doc_003"), {
        driver_id: "driver_doc_999", // usurpation
        type: "identity",
        status: "uploaded",
      })
    );
  });

  it("un chauffeur NE PEUT PAS modifier le statut de son propre document (Cloud Function only : validateDriverDocument)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_004"), {
        driver_id: "driver_doc_004",
        type: "vehicle_registration",
        status: "uploaded",
      });
    });

    const driver = testEnv.authenticatedContext("driver_doc_004", { role: "driver" });
    await assertFails(
      updateDoc(doc(driver.firestore(), "driver_documents/doc_004"), { status: "approved" })
    );
  });

  it("un analyste NE PEUT PAS non plus modifier directement le statut (même privilégié, doit passer par la Cloud Function)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_005"), {
        driver_id: "driver_doc_005",
        type: "identity",
        status: "uploaded",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_doc_001", { role: "analyst" });
    await assertFails(
      updateDoc(doc(analyst.firestore(), "driver_documents/doc_005"), { status: "approved" })
    );
  });

  it("un analyste PEUT lire n'importe quel document chauffeur ; un autre chauffeur ne peut PAS (accès croisé bloqué)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_006"), {
        driver_id: "driver_doc_006",
        type: "insurance",
        status: "uploaded",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_doc_002", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "driver_documents/doc_006")));

    const otherDriver = testEnv.authenticatedContext("driver_doc_stranger", { role: "driver" });
    await assertFails(getDoc(doc(otherDriver.firestore(), "driver_documents/doc_006")));
  });

  it("suppression toujours interdite, même pour le chauffeur propriétaire ou un admin", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_documents/doc_007"), {
        driver_id: "driver_doc_007",
        type: "identity",
        status: "uploaded",
      });
    });

    const driver = testEnv.authenticatedContext("driver_doc_007", { role: "driver" });
    await assertFails(deleteDoc(doc(driver.firestore(), "driver_documents/doc_007")));

    const admin = testEnv.authenticatedContext("admin_doc_001", { role: "admin" });
    await assertFails(deleteDoc(doc(admin.firestore(), "driver_documents/doc_007")));
  });
});

// -----------------------------------------------------------------------
// driver_vehicles/{vehicleId} — véhicule chauffeur, vérification analyste
// -----------------------------------------------------------------------
describe("Security Rules — driver_vehicles/{vehicleId}", () => {
  it("un chauffeur peut créer SON véhicule en is_verified=false", async () => {
    const driver = testEnv.authenticatedContext("driver_veh_001", { role: "driver" });
    await assertSucceeds(
      setDoc(doc(driver.firestore(), "driver_vehicles/veh_001"), {
        driver_id: "driver_veh_001",
        plate: "ABC-123",
        is_verified: false,
      })
    );
  });

  it("un chauffeur ne peut PAS créer un véhicule déjà 'is_verified: true' (auto-vérification interdite)", async () => {
    const driver = testEnv.authenticatedContext("driver_veh_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_vehicles/veh_002"), {
        driver_id: "driver_veh_002",
        plate: "XYZ-999",
        is_verified: true,
      })
    );
  });

  it("un chauffeur peut modifier ses propres champs non protégés (ex: plate) tant que is_verified/driver_id restent inchangés", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_003"), {
        driver_id: "driver_veh_003",
        plate: "OLD-000",
        is_verified: false,
      });
    });

    const driver = testEnv.authenticatedContext("driver_veh_003", { role: "driver" });
    await assertSucceeds(
      updateDoc(doc(driver.firestore(), "driver_vehicles/veh_003"), {
        driver_id: "driver_veh_003",
        plate: "NEW-111",
        is_verified: false,
      })
    );
  });

  it("un chauffeur NE PEUT PAS s'auto-vérifier son véhicule (is_verified false -> true)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_004"), {
        driver_id: "driver_veh_004",
        plate: "SELF-001",
        is_verified: false,
      });
    });

    const driver = testEnv.authenticatedContext("driver_veh_004", { role: "driver" });
    await assertFails(
      updateDoc(doc(driver.firestore(), "driver_vehicles/veh_004"), {
        driver_id: "driver_veh_004",
        plate: "SELF-001",
        is_verified: true, // tentative d'auto-vérification
      })
    );
  });

  it("un analyste PEUT vérifier le véhicule d'un chauffeur (is_verified -> true)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_005"), {
        driver_id: "driver_veh_005",
        plate: "APPROVE-001",
        is_verified: false,
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_veh_001", { role: "analyst" });
    await assertSucceeds(
      updateDoc(doc(analyst.firestore(), "driver_vehicles/veh_005"), { is_verified: true })
    );
  });

  it("le chauffeur propriétaire peut supprimer son véhicule ; un autre chauffeur ne peut pas", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_006"), {
        driver_id: "driver_veh_006",
        plate: "DELETE-001",
        is_verified: false,
      });
    });

    const stranger = testEnv.authenticatedContext("driver_veh_stranger", { role: "driver" });
    await assertFails(deleteDoc(doc(stranger.firestore(), "driver_vehicles/veh_006")));

    const owner = testEnv.authenticatedContext("driver_veh_006", { role: "driver" });
    await assertSucceeds(deleteDoc(doc(owner.firestore(), "driver_vehicles/veh_006")));
  });

  it("un customer ne peut ni lire ni écrire un véhicule chauffeur (accès croisé de rôle bloqué)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/veh_007"), {
        driver_id: "driver_veh_007",
        plate: "CUST-BLOCK",
        is_verified: true,
      });
    });

    const customer = testEnv.authenticatedContext("customer_veh_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_vehicles/veh_007")));
  });
});

// -----------------------------------------------------------------------
// driver_internal_notes/{noteId} — Cloud Function only, jamais visible au chauffeur
// -----------------------------------------------------------------------
describe("Security Rules — driver_internal_notes/{noteId} : write Cloud Functions only", () => {
  it("un analyste PEUT lire les notes internes", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_001"), {
        driver_id: "driver_note_001",
        author_user_id: "analyst_note_001",
        text: "Note de test",
      });
    });

    const analyst = testEnv.authenticatedContext("analyst_note_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "driver_internal_notes/note_001")));
  });

  it("le chauffeur CONCERNÉ par la note NE PEUT PAS la lire (jamais visible au chauffeur)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_002"), {
        driver_id: "driver_note_002",
        author_user_id: "analyst_note_002",
        text: "Note confidentielle",
      });
    });

    const concernedDriver = testEnv.authenticatedContext("driver_note_002", { role: "driver" });
    await assertFails(getDoc(doc(concernedDriver.firestore(), "driver_internal_notes/note_002")));
  });

  it("un customer ne peut pas lire les notes internes", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_003"), {
        driver_id: "driver_note_003",
        text: "Note",
      });
    });

    const customer = testEnv.authenticatedContext("customer_note_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_internal_notes/note_003")));
  });

  it("aucun rôle, même super_admin, ne peut écrire une note interne directement (Cloud Function only : addDriverInternalNote)", async () => {
    const superAdmin = testEnv.authenticatedContext("super_admin_note_001", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "driver_internal_notes/note_fake_001"), {
        driver_id: "driver_note_004",
        author_user_id: "super_admin_note_001",
        author_role: "super_admin",
        text: "Note falsifiée créée directement depuis le client",
      })
    );
  });

  it("une note interne existante ne peut pas être modifiée (immuabilité, même par un admin)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_005"), {
        driver_id: "driver_note_005",
        text: "Texte original",
      });
    });

    const admin = testEnv.authenticatedContext("admin_note_001", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "driver_internal_notes/note_005"), {
        text: "Texte modifié frauduleusement",
      })
    );
  });

  it("une note interne ne peut pas être supprimée, même par un super_admin", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_internal_notes/note_006"), {
        driver_id: "driver_note_006",
        text: "Note",
      });
    });

    const superAdmin = testEnv.authenticatedContext("super_admin_note_002", { role: "super_admin" });
    await assertFails(deleteDoc(doc(superAdmin.firestore(), "driver_internal_notes/note_006")));
  });
});

// -----------------------------------------------------------------------
// driver_locations/{driverId} + driver_locations/{driverId}/history/{eventId}
// (Phase 5, partie 2 — trajet réellement parcouru).
// -----------------------------------------------------------------------
describe("Security Rules — driver_locations/{driverId} : position courante", () => {
  it("le chauffeur PEUT lire ET écrire sa propre position", async () => {
    const driver = testEnv.authenticatedContext("track_driver_001", { role: "driver" });
    await assertSucceeds(
      setDoc(doc(driver.firestore(), "driver_locations/track_driver_001"), {
        driver_id: "track_driver_001",
        latitude: 45.5,
        longitude: -73.5,
        active_delivery_id: null,
      })
    );
    await assertSucceeds(getDoc(doc(driver.firestore(), "driver_locations/track_driver_001")));
  });

  it("[négatif] un chauffeur NE PEUT PAS écrire la position d'un AUTRE chauffeur", async () => {
    const driver = testEnv.authenticatedContext("track_driver_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_locations/track_driver_other"), {
        driver_id: "track_driver_other",
        latitude: 45.5,
        longitude: -73.5,
      })
    );
  });

  it("[négatif] un client SANS mission active avec ce chauffeur NE PEUT PAS lire sa position", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/track_driver_003"), {
        driver_id: "track_driver_003",
        latitude: 45.5,
        longitude: -73.5,
        active_delivery_id: null,
      });
    });
    const customer = testEnv.authenticatedContext("track_customer_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_locations/track_driver_003")));
  });

  it("un client AVEC une mission active assignée à ce chauffeur PEUT lire sa position", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/track_mission_001"), {
        customer_id: "track_customer_002",
        driver_id: "track_driver_004",
        status: "in_transit",
      });
      await setDoc(doc(ctx.firestore(), "driver_locations/track_driver_004"), {
        driver_id: "track_driver_004",
        latitude: 45.5,
        longitude: -73.5,
        active_delivery_id: "track_mission_001",
      });
    });
    const customer = testEnv.authenticatedContext("track_customer_002", { role: "customer" });
    await assertSucceeds(getDoc(doc(customer.firestore(), "driver_locations/track_driver_004")));
  });

  it("[négatif] un client AVEC une mission active mais pour un AUTRE chauffeur NE PEUT PAS lire cette position", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/track_mission_002"), {
        customer_id: "track_customer_003",
        driver_id: "track_driver_005",
        status: "in_transit",
      });
      await setDoc(doc(ctx.firestore(), "driver_locations/track_driver_006"), {
        driver_id: "track_driver_006",
        latitude: 45.5,
        longitude: -73.5,
        // active_delivery_id pointe vers une mission dont ce client N'EST
        // PAS le customer_id.
        active_delivery_id: "track_mission_002",
      });
    });
    const stranger = testEnv.authenticatedContext("track_customer_999", { role: "customer" });
    await assertFails(getDoc(doc(stranger.firestore(), "driver_locations/track_driver_006")));
  });

  it("[négatif] un client dont la mission active n'est PLUS liée à ce chauffeur (active_delivery_id null après annulation) NE PEUT PLUS lire sa position", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/track_mission_003"), {
        customer_id: "track_customer_004",
        driver_id: "track_driver_007",
        status: "cancelled",
      });
      // Simule le nettoyage effectué par onMissionEndedClearTracking après
      // l'annulation : active_delivery_id remis à null.
      await setDoc(doc(ctx.firestore(), "driver_locations/track_driver_007"), {
        driver_id: "track_driver_007",
        latitude: 45.5,
        longitude: -73.5,
        active_delivery_id: null,
      });
    });
    const customer = testEnv.authenticatedContext("track_customer_004", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_locations/track_driver_007")));
  });

  it("un analyste peut lire la position de N'IMPORTE QUEL chauffeur", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/track_driver_008"), {
        driver_id: "track_driver_008",
        latitude: 45.5,
        longitude: -73.5,
        active_delivery_id: null,
      });
    });
    const analyst = testEnv.authenticatedContext("track_analyst_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "driver_locations/track_driver_008")));
  });

  it("[négatif] un utilisateur NON authentifié ne peut ni lire ni écrire une position", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/track_driver_009"), {
        driver_id: "track_driver_009",
        latitude: 45.5,
        longitude: -73.5,
        active_delivery_id: null,
      });
    });
    const anon = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(anon.firestore(), "driver_locations/track_driver_009")));
    await assertFails(
      setDoc(doc(anon.firestore(), "driver_locations/track_driver_010"), {
        driver_id: "track_driver_010",
        latitude: 45.5,
        longitude: -73.5,
      })
    );
  });
});

describe("Security Rules — driver_locations/{driverId}/history/{eventId} : trajet parcouru (Phase 5, partie 2)", () => {
  it("[négatif] écriture DIRECTE (bypass recordTrackingPoint) est TOUJOURS interdite, même pour le chauffeur propriétaire", async () => {
    const driver = testEnv.authenticatedContext("hist_driver_001", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "driver_locations/hist_driver_001/history/point_001"), {
        delivery_id: "hist_mission_001",
        latitude: 45.5,
        longitude: -73.5,
      })
    );
  });

  it("[négatif] écriture DIRECTE est interdite même pour un super_admin (Cloud Functions only)", async () => {
    const superAdmin = testEnv.authenticatedContext("hist_super_admin_001", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "driver_locations/hist_driver_002/history/point_002"), {
        delivery_id: "hist_mission_002",
        latitude: 45.5,
        longitude: -73.5,
      })
    );
  });

  it("le chauffeur PEUT lire son PROPRE historique de trajet", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_003/history/point_003"), {
        delivery_id: "hist_mission_003",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const driver = testEnv.authenticatedContext("hist_driver_003", { role: "driver" });
    await assertSucceeds(
      getDoc(doc(driver.firestore(), "driver_locations/hist_driver_003/history/point_003"))
    );
  });

  it("[négatif] un AUTRE chauffeur NE PEUT PAS lire l'historique d'un chauffeur tiers", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_004/history/point_004"), {
        delivery_id: "hist_mission_004",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const otherDriver = testEnv.authenticatedContext("hist_driver_005", { role: "driver" });
    await assertFails(
      getDoc(doc(otherDriver.firestore(), "driver_locations/hist_driver_004/history/point_004"))
    );
  });

  it("un client PROPRIÉTAIRE de la mission référencée par delivery_id PEUT lire ce point d'historique", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/hist_mission_005"), {
        customer_id: "hist_customer_001",
        driver_id: "hist_driver_006",
        status: "in_transit",
      });
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_006/history/point_005"), {
        delivery_id: "hist_mission_005",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const customer = testEnv.authenticatedContext("hist_customer_001", { role: "customer" });
    await assertSucceeds(
      getDoc(doc(customer.firestore(), "driver_locations/hist_driver_006/history/point_005"))
    );
  });

  it("[négatif] un client qui N'EST PAS le customer_id de la mission référencée NE PEUT PAS lire ce point", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "delivery_requests/hist_mission_006"), {
        customer_id: "hist_customer_002",
        driver_id: "hist_driver_007",
        status: "in_transit",
      });
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_007/history/point_006"), {
        delivery_id: "hist_mission_006",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const stranger = testEnv.authenticatedContext("hist_customer_999", { role: "customer" });
    await assertFails(
      getDoc(doc(stranger.firestore(), "driver_locations/hist_driver_007/history/point_006"))
    );
  });

  it("un analyste peut lire N'IMPORTE QUEL point d'historique", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_008/history/point_007"), {
        delivery_id: "hist_mission_007",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const analyst = testEnv.authenticatedContext("hist_analyst_001", { role: "analyst" });
    await assertSucceeds(
      getDoc(doc(analyst.firestore(), "driver_locations/hist_driver_008/history/point_007"))
    );
  });

  it("[négatif] un utilisateur NON authentifié ne peut ni lire ni écrire un point d'historique", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_009/history/point_008"), {
        delivery_id: "hist_mission_008",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const anon = testEnv.unauthenticatedContext();
    await assertFails(
      getDoc(doc(anon.firestore(), "driver_locations/hist_driver_009/history/point_008"))
    );
    await assertFails(
      setDoc(doc(anon.firestore(), "driver_locations/hist_driver_009/history/point_009"), {
        delivery_id: "hist_mission_008",
        latitude: 45.5,
        longitude: -73.5,
      })
    );
  });

  it("[négatif] même le chauffeur propriétaire NE PEUT PAS supprimer un point d'historique (immuable, Cloud Functions only)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_locations/hist_driver_010/history/point_010"), {
        delivery_id: "hist_mission_009",
        latitude: 45.5,
        longitude: -73.5,
      });
    });
    const driver = testEnv.authenticatedContext("hist_driver_010", { role: "driver" });
    await assertFails(
      deleteDoc(doc(driver.firestore(), "driver_locations/hist_driver_010/history/point_010"))
    );
  });
});

// -----------------------------------------------------------------------
// users/{uid}/notifications/{notificationId} (Phase 5, partie 3)
// -----------------------------------------------------------------------
describe("Security Rules — users/{uid}/notifications/{notificationId}", () => {
  async function seedNotification(userId: string, notifId: string, overrides: Record<string, unknown> = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${userId}/notifications/${notifId}`), {
        id: notifId,
        type: "driver_assigned",
        title_key: "notif_driver_assigned_title",
        body_key: "notif_driver_assigned_body",
        is_read: false,
        created_at: 1,
        related_mission_id: "notif_mission_001",
        metadata: {},
        ...overrides,
      });
    });
  }

  it("un utilisateur peut lire ses PROPRES notifications", async () => {
    await seedNotification("notif_user_001", "notif_a");
    const owner = testEnv.authenticatedContext("notif_user_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "users/notif_user_001/notifications/notif_a")));
  });

  it("un AUTRE utilisateur ne peut PAS lire les notifications d'un autre (accès croisé bloqué)", async () => {
    await seedNotification("notif_user_002", "notif_b");
    const intruder = testEnv.authenticatedContext("notif_user_003", { role: "customer" });
    await assertFails(getDoc(doc(intruder.firestore(), "users/notif_user_002/notifications/notif_b")));
  });

  it("un utilisateur NON authentifié ne peut PAS lire une notification", async () => {
    await seedNotification("notif_user_004", "notif_c");
    const anon = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(anon.firestore(), "users/notif_user_004/notifications/notif_c")));
  });

  it("le propriétaire PEUT marquer sa notification comme lue (is_read uniquement)", async () => {
    await seedNotification("notif_user_005", "notif_d");
    const owner = testEnv.authenticatedContext("notif_user_005", { role: "customer" });
    await assertSucceeds(
      updateDoc(doc(owner.firestore(), "users/notif_user_005/notifications/notif_d"), {
        is_read: true,
      })
    );
  });

  it("un AUTRE utilisateur ne peut PAS marquer comme lue la notification de quelqu'un d'autre", async () => {
    await seedNotification("notif_user_006", "notif_e");
    const intruder = testEnv.authenticatedContext("notif_user_007", { role: "customer" });
    await assertFails(
      updateDoc(doc(intruder.firestore(), "users/notif_user_006/notifications/notif_e"), {
        is_read: true,
      })
    );
  });

  it("le propriétaire ne peut PAS modifier un champ métier sensible (title_key, body_key, related_mission_id, type)", async () => {
    await seedNotification("notif_user_008", "notif_f");
    const owner = testEnv.authenticatedContext("notif_user_008", { role: "customer" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "users/notif_user_008/notifications/notif_f"), {
        title_key: "notif_completed_title",
      })
    );
    await assertFails(
      updateDoc(doc(owner.firestore(), "users/notif_user_008/notifications/notif_f"), {
        related_mission_id: "some_other_mission",
      })
    );
    // Une écriture combinant is_read + un champ sensible doit AUSSI être
    // refusée (affectedKeys().hasOnly(['is_read']) échoue dès qu'une autre
    // clé est modifiée simultanément).
    await assertFails(
      updateDoc(doc(owner.firestore(), "users/notif_user_008/notifications/notif_f"), {
        is_read: true,
        type: "cancelled",
      })
    );
  });

  it("un client ne peut PAS fabriquer arbitrairement une notification serveur (create direct interdit, Cloud Functions only)", async () => {
    const attacker = testEnv.authenticatedContext("notif_user_009", { role: "customer" });
    await assertFails(
      setDoc(doc(attacker.firestore(), "users/notif_user_009/notifications/fake_notif"), {
        id: "fake_notif",
        type: "completed",
        title_key: "notif_completed_title",
        body_key: "notif_completed_body",
        is_read: false,
        created_at: 1,
        related_mission_id: "fake_mission",
        metadata: {},
      })
    );
  });

  it("un client ne peut PAS changer le userId effectif d'une notification en la recréant sous un autre uid après suppression, ni la supprimer directement", async () => {
    await seedNotification("notif_user_010", "notif_g");
    const owner = testEnv.authenticatedContext("notif_user_010", { role: "customer" });
    // Suppression interdite (Cloud Functions only également).
    await assertFails(deleteDoc(doc(owner.firestore(), "users/notif_user_010/notifications/notif_g")));
    // Un autre utilisateur ne peut pas non plus créer un document dans la
    // sous-collection d'un tiers pour usurper un "userId" logique.
    const intruder = testEnv.authenticatedContext("notif_user_011", { role: "customer" });
    await assertFails(
      setDoc(doc(intruder.firestore(), "users/notif_user_010/notifications/notif_h"), {
        id: "notif_h",
        type: "completed",
        title_key: "notif_completed_title",
        body_key: "notif_completed_body",
        is_read: false,
        created_at: 1,
        related_mission_id: "fake_mission",
        metadata: {},
      })
    );
  });

  it("analyst/admin n'ont PAS de droit de lecture spécial sur les notifications d'un tiers (contrairement à users/{uid} — règle notifications strictement propriétaire)", async () => {
    await seedNotification("notif_user_012", "notif_i");
    const analyst = testEnv.authenticatedContext("notif_analyst_001", { role: "analyst" });
    await assertFails(getDoc(doc(analyst.firestore(), "users/notif_user_012/notifications/notif_i")));
  });
});

// -----------------------------------------------------------------------
// disputes/{disputeId} — Bloc L : lecture analyst ou supérieur uniquement,
// aucune écriture cliente (point 21, Phase 6).
// -----------------------------------------------------------------------
describe("Security Rules — disputes/{disputeId} (Bloc L)", () => {
  async function seedDispute(disputeId: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `disputes/${disputeId}`), {
        dispute_id: disputeId,
        payment_id: "payment_dispute_001",
        mission_id: "mission_dispute_001",
        status: "opened",
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire un litige", async () => {
    await seedDispute("dispute_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "disputes/dispute_001")));
  });

  it("un customer ne peut PAS lire un litige", async () => {
    await seedDispute("dispute_002");
    const customer = testEnv.authenticatedContext("customer_dispute_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "disputes/dispute_002")));
  });

  it("un driver ne peut PAS lire un litige", async () => {
    await seedDispute("dispute_003");
    const driver = testEnv.authenticatedContext("driver_dispute_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "disputes/dispute_003")));
  });

  it("un analyst PEUT lire un litige", async () => {
    await seedDispute("dispute_004");
    const analyst = testEnv.authenticatedContext("analyst_dispute_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "disputes/dispute_004")));
  });

  it("un admin PEUT lire un litige", async () => {
    await seedDispute("dispute_005");
    const admin = testEnv.authenticatedContext("admin_dispute_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "disputes/dispute_005")));
  });

  it("un super_admin PEUT lire un litige", async () => {
    await seedDispute("dispute_006");
    const superAdmin = testEnv.authenticatedContext("super_admin_dispute_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "disputes/dispute_006")));
  });

  it("aucune écriture directe n'est autorisée, même pour analyst/admin/super_admin", async () => {
    await seedDispute("dispute_007");

    const analyst = testEnv.authenticatedContext("analyst_dispute_002", { role: "analyst" });
    await assertFails(
      updateDoc(doc(analyst.firestore(), "disputes/dispute_007"), { status: "won" })
    );

    const admin = testEnv.authenticatedContext("admin_dispute_002", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "disputes/dispute_007"), { status: "won" })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_dispute_002", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "disputes/dispute_007"), { status: "won" })
    );
  });

  it("un customer/driver ne peut pas écrire un litige (create direct)", async () => {
    const customer = testEnv.authenticatedContext("customer_dispute_002", { role: "customer" });
    await assertFails(
      setDoc(doc(customer.firestore(), "disputes/dispute_fake_001"), {
        dispute_id: "dispute_fake_001",
        status: "opened",
      })
    );

    const driver = testEnv.authenticatedContext("driver_dispute_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "disputes/dispute_fake_002"), {
        dispute_id: "dispute_fake_002",
        status: "opened",
      })
    );
  });
});

// -----------------------------------------------------------------------
// reconciliation_reports/{reportId} — Bloc L : lecture admin ou supérieur
// UNIQUEMENT (analyst explicitement refusé), aucune écriture cliente
// (point 27, Phase 6).
// -----------------------------------------------------------------------
describe("Security Rules — reconciliation_reports/{reportId} (Bloc L)", () => {
  async function seedReport(reportId: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `reconciliation_reports/${reportId}`), {
        report_id: reportId,
        status: "open",
        anomalies_count: 0,
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire un rapport de réconciliation", async () => {
    await seedReport("recon_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "reconciliation_reports/recon_001")));
  });

  it("un customer ne peut PAS lire un rapport de réconciliation", async () => {
    await seedReport("recon_002");
    const customer = testEnv.authenticatedContext("customer_recon_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "reconciliation_reports/recon_002")));
  });

  it("un driver ne peut PAS lire un rapport de réconciliation", async () => {
    await seedReport("recon_003");
    const driver = testEnv.authenticatedContext("driver_recon_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "reconciliation_reports/recon_003")));
  });

  it("un analyst NE PEUT PAS lire un rapport de réconciliation (règle plus stricte que la moyenne : admin+ uniquement)", async () => {
    await seedReport("recon_004");
    const analyst = testEnv.authenticatedContext("analyst_recon_001", { role: "analyst" });
    await assertFails(getDoc(doc(analyst.firestore(), "reconciliation_reports/recon_004")));
  });

  it("un admin PEUT lire un rapport de réconciliation", async () => {
    await seedReport("recon_005");
    const admin = testEnv.authenticatedContext("admin_recon_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "reconciliation_reports/recon_005")));
  });

  it("un super_admin PEUT lire un rapport de réconciliation", async () => {
    await seedReport("recon_006");
    const superAdmin = testEnv.authenticatedContext("super_admin_recon_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "reconciliation_reports/recon_006")));
  });

  it("aucune écriture directe n'est autorisée, même pour admin/super_admin", async () => {
    await seedReport("recon_007");

    const admin = testEnv.authenticatedContext("admin_recon_002", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "reconciliation_reports/recon_007"), { status: "resolved" })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_recon_002", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "reconciliation_reports/recon_007"), { status: "resolved" })
    );
  });

  it("un analyst ne peut pas non plus créer un rapport directement", async () => {
    const analyst = testEnv.authenticatedContext("analyst_recon_002", { role: "analyst" });
    await assertFails(
      setDoc(doc(analyst.firestore(), "reconciliation_reports/recon_fake_001"), {
        report_id: "recon_fake_001",
        status: "open",
      })
    );
  });
});

// -----------------------------------------------------------------------
// tax_configs/{jurisdiction} — Bloc L : lecture publique (tout utilisateur
// authentifié), aucune écriture cliente (point 16, Phase 6).
// -----------------------------------------------------------------------
describe("Security Rules — tax_configs/{jurisdiction} (Bloc L)", () => {
  async function seedTaxConfig(jurisdiction: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `tax_configs/${jurisdiction}`), {
        jurisdiction,
        rate: 0.14975,
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire une configuration de taxe", async () => {
    await seedTaxConfig("QC");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "tax_configs/QC")));
  });

  it("un customer PEUT lire une configuration de taxe", async () => {
    await seedTaxConfig("QC_customer");
    const customer = testEnv.authenticatedContext("customer_tax_001", { role: "customer" });
    await assertSucceeds(getDoc(doc(customer.firestore(), "tax_configs/QC_customer")));
  });

  it("un driver PEUT lire une configuration de taxe", async () => {
    await seedTaxConfig("QC_driver");
    const driver = testEnv.authenticatedContext("driver_tax_001", { role: "driver" });
    await assertSucceeds(getDoc(doc(driver.firestore(), "tax_configs/QC_driver")));
  });

  it("un analyst PEUT lire une configuration de taxe", async () => {
    await seedTaxConfig("QC_analyst");
    const analyst = testEnv.authenticatedContext("analyst_tax_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "tax_configs/QC_analyst")));
  });

  it("un admin PEUT lire une configuration de taxe", async () => {
    await seedTaxConfig("QC_admin");
    const admin = testEnv.authenticatedContext("admin_tax_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "tax_configs/QC_admin")));
  });

  it("un super_admin PEUT lire une configuration de taxe", async () => {
    await seedTaxConfig("QC_super_admin");
    const superAdmin = testEnv.authenticatedContext("super_admin_tax_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "tax_configs/QC_super_admin")));
  });

  it("aucune écriture directe n'est autorisée, quel que soit le rôle (même super_admin)", async () => {
    await seedTaxConfig("QC_write");

    const customer = testEnv.authenticatedContext("customer_tax_002", { role: "customer" });
    await assertFails(
      updateDoc(doc(customer.firestore(), "tax_configs/QC_write"), { rate: 0 })
    );

    const admin = testEnv.authenticatedContext("admin_tax_002", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "tax_configs/QC_write"), { rate: 0 })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_tax_002", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "tax_configs/QC_write"), { rate: 0 })
    );
  });

  it("aucune création directe n'est autorisée, même pour super_admin", async () => {
    const superAdmin = testEnv.authenticatedContext("super_admin_tax_003", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "tax_configs/QC_fake"), {
        jurisdiction: "QC_fake",
        rate: 0.5,
      })
    );
  });
});

// -----------------------------------------------------------------------
// payout_policy_configs/{configId} — Bloc L : lecture admin ou supérieur
// UNIQUEMENT (analyst explicitement refusé), aucune écriture cliente
// (point 9, Phase 6).
// -----------------------------------------------------------------------
describe("Security Rules — payout_policy_configs/{configId} (Bloc L)", () => {
  async function seedPolicy(configId: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `payout_policy_configs/${configId}`), {
        config_id: configId,
        default_hold_days: 3,
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire la politique de versement", async () => {
    await seedPolicy("policy_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "payout_policy_configs/policy_001")));
  });

  it("un customer ne peut PAS lire la politique de versement", async () => {
    await seedPolicy("policy_002");
    const customer = testEnv.authenticatedContext("customer_policy_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "payout_policy_configs/policy_002")));
  });

  it("un driver ne peut PAS lire la politique de versement", async () => {
    await seedPolicy("policy_003");
    const driver = testEnv.authenticatedContext("driver_policy_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "payout_policy_configs/policy_003")));
  });

  it("un analyst NE PEUT PAS lire la politique de versement (règle plus stricte : admin+ uniquement)", async () => {
    await seedPolicy("policy_004");
    const analyst = testEnv.authenticatedContext("analyst_policy_001", { role: "analyst" });
    await assertFails(getDoc(doc(analyst.firestore(), "payout_policy_configs/policy_004")));
  });

  it("un admin PEUT lire la politique de versement", async () => {
    await seedPolicy("policy_005");
    const admin = testEnv.authenticatedContext("admin_policy_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "payout_policy_configs/policy_005")));
  });

  it("un super_admin PEUT lire la politique de versement", async () => {
    await seedPolicy("policy_006");
    const superAdmin = testEnv.authenticatedContext("super_admin_policy_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "payout_policy_configs/policy_006")));
  });

  it("aucune écriture directe n'est autorisée, même pour admin/super_admin (Cloud Function updatePayoutPolicyConfiguration only)", async () => {
    await seedPolicy("policy_007");

    const admin = testEnv.authenticatedContext("admin_policy_002", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "payout_policy_configs/policy_007"), { default_hold_days: 0 })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_policy_002", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "payout_policy_configs/policy_007"), { default_hold_days: 0 })
    );
  });

  it("un analyst ne peut pas non plus créer une politique directement", async () => {
    const analyst = testEnv.authenticatedContext("analyst_policy_002", { role: "analyst" });
    await assertFails(
      setDoc(doc(analyst.firestore(), "payout_policy_configs/policy_fake_001"), {
        config_id: "policy_fake_001",
        default_hold_days: 0,
      })
    );
  });
});

// -----------------------------------------------------------------------
// payment_profiles/{customerId} — Bloc T : lecture propriétaire ou
// analyst+ (règle exacte : `uid() == customerId || isAnalystOrAbove()`),
// aucune écriture cliente (référence Stripe client, pas de donnée de
// carte sensible).
// -----------------------------------------------------------------------
describe("Security Rules — payment_profiles/{customerId} (Bloc T)", () => {
  async function seedProfile(customerId: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `payment_profiles/${customerId}`), {
        customer_id: customerId,
        stripe_customer_id: "cus_fake_001",
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire un profil de paiement", async () => {
    await seedProfile("customer_pp_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "payment_profiles/customer_pp_001")));
  });

  it("le customer propriétaire PEUT lire son propre profil de paiement", async () => {
    await seedProfile("customer_pp_002");
    const owner = testEnv.authenticatedContext("customer_pp_002", { role: "customer" });
    await assertSucceeds(getDoc(doc(owner.firestore(), "payment_profiles/customer_pp_002")));
  });

  it("un autre customer (non propriétaire) ne peut PAS lire ce profil de paiement", async () => {
    await seedProfile("customer_pp_003");
    const other = testEnv.authenticatedContext("customer_pp_other_001", { role: "customer" });
    await assertFails(getDoc(doc(other.firestore(), "payment_profiles/customer_pp_003")));
  });

  it("un driver ne peut PAS lire un profil de paiement (aucune règle explicite ne l'autorise)", async () => {
    await seedProfile("customer_pp_004");
    const driver = testEnv.authenticatedContext("driver_pp_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "payment_profiles/customer_pp_004")));
  });

  it("un analyst PEUT lire n'importe quel profil de paiement", async () => {
    await seedProfile("customer_pp_005");
    const analyst = testEnv.authenticatedContext("analyst_pp_001", { role: "analyst" });
    await assertSucceeds(getDoc(doc(analyst.firestore(), "payment_profiles/customer_pp_005")));
  });

  it("un admin PEUT lire n'importe quel profil de paiement", async () => {
    await seedProfile("customer_pp_006");
    const admin = testEnv.authenticatedContext("admin_pp_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "payment_profiles/customer_pp_006")));
  });

  it("un super_admin PEUT lire n'importe quel profil de paiement", async () => {
    await seedProfile("customer_pp_007");
    const superAdmin = testEnv.authenticatedContext("super_admin_pp_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "payment_profiles/customer_pp_007")));
  });

  it("le propriétaire ne peut PAS écrire/modifier directement son propre profil de paiement", async () => {
    await seedProfile("customer_pp_008");
    const owner = testEnv.authenticatedContext("customer_pp_008", { role: "customer" });
    await assertFails(
      updateDoc(doc(owner.firestore(), "payment_profiles/customer_pp_008"), {
        stripe_customer_id: "cus_hacked",
      })
    );
  });

  it("un analyst ne peut PAS écrire directement un profil de paiement", async () => {
    await seedProfile("customer_pp_009");
    const analyst = testEnv.authenticatedContext("analyst_pp_002", { role: "analyst" });
    await assertFails(
      updateDoc(doc(analyst.firestore(), "payment_profiles/customer_pp_009"), {
        stripe_customer_id: "cus_hacked",
      })
    );
  });

  it("un admin ne peut PAS écrire directement un profil de paiement", async () => {
    await seedProfile("customer_pp_010");
    const admin = testEnv.authenticatedContext("admin_pp_002", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "payment_profiles/customer_pp_010"), {
        stripe_customer_id: "cus_hacked",
      })
    );
  });

  it("un super_admin ne peut PAS écrire directement un profil de paiement (Cloud Functions only)", async () => {
    await seedProfile("customer_pp_011");
    const superAdmin = testEnv.authenticatedContext("super_admin_pp_002", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "payment_profiles/customer_pp_011"), {
        stripe_customer_id: "cus_hacked",
      })
    );
  });
});

// -----------------------------------------------------------------------
// idempotency_keys/{key} — Bloc T : collection totalement inaccessible
// côté client, quel que soit le rôle. Règle exacte : `allow read, write:
// if false;` — verrous internes Cloud Functions / Admin SDK uniquement.
// -----------------------------------------------------------------------
describe("Security Rules — idempotency_keys/{key} (Bloc T)", () => {
  async function seedKey(key: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `idempotency_keys/${key}`), {
        key,
        locked_at: Date.now(),
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire une clé d'idempotence", async () => {
    await seedKey("idem_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "idempotency_keys/idem_001")));
  });

  it("un customer ne peut PAS lire une clé d'idempotence", async () => {
    await seedKey("idem_002");
    const customer = testEnv.authenticatedContext("customer_idem_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "idempotency_keys/idem_002")));
  });

  it("un driver ne peut PAS lire une clé d'idempotence", async () => {
    await seedKey("idem_003");
    const driver = testEnv.authenticatedContext("driver_idem_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "idempotency_keys/idem_003")));
  });

  it("un analyst ne peut PAS lire une clé d'idempotence", async () => {
    await seedKey("idem_004");
    const analyst = testEnv.authenticatedContext("analyst_idem_001", { role: "analyst" });
    await assertFails(getDoc(doc(analyst.firestore(), "idempotency_keys/idem_004")));
  });

  it("un admin ne peut PAS lire une clé d'idempotence", async () => {
    await seedKey("idem_005");
    const admin = testEnv.authenticatedContext("admin_idem_001", { role: "admin" });
    await assertFails(getDoc(doc(admin.firestore(), "idempotency_keys/idem_005")));
  });

  it("un super_admin ne peut PAS lire une clé d'idempotence (même le rôle le plus élevé)", async () => {
    await seedKey("idem_006");
    const superAdmin = testEnv.authenticatedContext("super_admin_idem_001", { role: "super_admin" });
    await assertFails(getDoc(doc(superAdmin.firestore(), "idempotency_keys/idem_006")));
  });

  it("un customer ne peut PAS écrire une clé d'idempotence", async () => {
    const customer = testEnv.authenticatedContext("customer_idem_002", { role: "customer" });
    await assertFails(
      setDoc(doc(customer.firestore(), "idempotency_keys/idem_fake_001"), { key: "idem_fake_001" })
    );
  });

  it("un driver ne peut PAS écrire une clé d'idempotence", async () => {
    const driver = testEnv.authenticatedContext("driver_idem_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "idempotency_keys/idem_fake_002"), { key: "idem_fake_002" })
    );
  });

  it("un analyst ne peut PAS écrire une clé d'idempotence", async () => {
    const analyst = testEnv.authenticatedContext("analyst_idem_002", { role: "analyst" });
    await assertFails(
      setDoc(doc(analyst.firestore(), "idempotency_keys/idem_fake_003"), { key: "idem_fake_003" })
    );
  });

  it("un admin ne peut PAS écrire une clé d'idempotence", async () => {
    const admin = testEnv.authenticatedContext("admin_idem_002", { role: "admin" });
    await assertFails(
      setDoc(doc(admin.firestore(), "idempotency_keys/idem_fake_004"), { key: "idem_fake_004" })
    );
  });

  it("un super_admin ne peut PAS écrire une clé d'idempotence (Cloud Functions / Admin SDK only)", async () => {
    const superAdmin = testEnv.authenticatedContext("super_admin_idem_002", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "idempotency_keys/idem_fake_005"), { key: "idem_fake_005" })
    );
  });
});

// -----------------------------------------------------------------------
// provider_webhook_events/{eventId} — Bloc T : lecture admin+ UNIQUEMENT
// (analyst explicitement refusé, règle exacte : `isAdminOrAbove()`),
// aucune écriture cliente. Les webhooks Stripe restent backend-only.
// -----------------------------------------------------------------------
describe("Security Rules — provider_webhook_events/{eventId} (Bloc T)", () => {
  async function seedEvent(eventId: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `provider_webhook_events/${eventId}`), {
        event_id: eventId,
        type: "payment_intent.succeeded",
        status: "processed",
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire un évènement webhook", async () => {
    await seedEvent("evt_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "provider_webhook_events/evt_001")));
  });

  it("un customer ne peut PAS lire un évènement webhook", async () => {
    await seedEvent("evt_002");
    const customer = testEnv.authenticatedContext("customer_evt_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "provider_webhook_events/evt_002")));
  });

  it("un driver ne peut PAS lire un évènement webhook", async () => {
    await seedEvent("evt_003");
    const driver = testEnv.authenticatedContext("driver_evt_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "provider_webhook_events/evt_003")));
  });

  it("un analyst NE PEUT PAS lire un évènement webhook (règle plus stricte : admin+ uniquement)", async () => {
    await seedEvent("evt_004");
    const analyst = testEnv.authenticatedContext("analyst_evt_001", { role: "analyst" });
    await assertFails(getDoc(doc(analyst.firestore(), "provider_webhook_events/evt_004")));
  });

  it("un admin PEUT lire un évènement webhook", async () => {
    await seedEvent("evt_005");
    const admin = testEnv.authenticatedContext("admin_evt_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "provider_webhook_events/evt_005")));
  });

  it("un super_admin PEUT lire un évènement webhook", async () => {
    await seedEvent("evt_006");
    const superAdmin = testEnv.authenticatedContext("super_admin_evt_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "provider_webhook_events/evt_006")));
  });

  it("un customer ne peut PAS écrire un évènement webhook", async () => {
    const customer = testEnv.authenticatedContext("customer_evt_002", { role: "customer" });
    await assertFails(
      setDoc(doc(customer.firestore(), "provider_webhook_events/evt_fake_001"), {
        event_id: "evt_fake_001",
      })
    );
  });

  it("un driver ne peut PAS écrire un évènement webhook", async () => {
    const driver = testEnv.authenticatedContext("driver_evt_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "provider_webhook_events/evt_fake_002"), {
        event_id: "evt_fake_002",
      })
    );
  });

  it("un analyst ne peut PAS écrire un évènement webhook", async () => {
    const analyst = testEnv.authenticatedContext("analyst_evt_002", { role: "analyst" });
    await assertFails(
      setDoc(doc(analyst.firestore(), "provider_webhook_events/evt_fake_003"), {
        event_id: "evt_fake_003",
      })
    );
  });

  it("un admin ne peut PAS écrire directement un évènement webhook", async () => {
    await seedEvent("evt_007");
    const admin = testEnv.authenticatedContext("admin_evt_002", { role: "admin" });
    await assertFails(
      updateDoc(doc(admin.firestore(), "provider_webhook_events/evt_007"), { status: "failed" })
    );
  });

  it("un super_admin ne peut PAS écrire directement un évènement webhook (processStripeWebhook / Admin SDK only)", async () => {
    await seedEvent("evt_008");
    const superAdmin = testEnv.authenticatedContext("super_admin_evt_002", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "provider_webhook_events/evt_008"), { status: "failed" })
    );
  });
});

// -----------------------------------------------------------------------
// audit_logs/{logId} — Bloc T : lecture admin+ UNIQUEMENT (analyst
// explicitement refusé, règle exacte : `isAdminOrAbove()`), écriture
// directe interdite quel que soit le rôle (Cloud Functions only).
// -----------------------------------------------------------------------
describe("Security Rules — audit_logs/{logId} (Bloc T)", () => {
  async function seedLog(logId: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `audit_logs/${logId}`), {
        log_id: logId,
        action: "dispute_opened",
      });
    });
  }

  it("un utilisateur NON authentifié ne peut PAS lire un log d'audit", async () => {
    await seedLog("log_001");
    const unauthed = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(unauthed.firestore(), "audit_logs/log_001")));
  });

  it("un customer ne peut PAS lire un log d'audit", async () => {
    await seedLog("log_002");
    const customer = testEnv.authenticatedContext("customer_log_001", { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "audit_logs/log_002")));
  });

  it("un driver ne peut PAS lire un log d'audit", async () => {
    await seedLog("log_003");
    const driver = testEnv.authenticatedContext("driver_log_001", { role: "driver" });
    await assertFails(getDoc(doc(driver.firestore(), "audit_logs/log_003")));
  });

  it("un analyst NE PEUT PAS lire un log d'audit (règle plus stricte : admin+ uniquement)", async () => {
    await seedLog("log_004");
    const analyst = testEnv.authenticatedContext("analyst_log_001", { role: "analyst" });
    await assertFails(getDoc(doc(analyst.firestore(), "audit_logs/log_004")));
  });

  it("un admin PEUT lire un log d'audit", async () => {
    await seedLog("log_005");
    const admin = testEnv.authenticatedContext("admin_log_001", { role: "admin" });
    await assertSucceeds(getDoc(doc(admin.firestore(), "audit_logs/log_005")));
  });

  it("un super_admin PEUT lire un log d'audit", async () => {
    await seedLog("log_006");
    const superAdmin = testEnv.authenticatedContext("super_admin_log_001", { role: "super_admin" });
    await assertSucceeds(getDoc(doc(superAdmin.firestore(), "audit_logs/log_006")));
  });

  it("aucun rôle ne peut écrire directement un log d'audit (create), même super_admin", async () => {
    const customer = testEnv.authenticatedContext("customer_log_002", { role: "customer" });
    await assertFails(
      setDoc(doc(customer.firestore(), "audit_logs/log_fake_001"), { log_id: "log_fake_001" })
    );

    const driver = testEnv.authenticatedContext("driver_log_002", { role: "driver" });
    await assertFails(
      setDoc(doc(driver.firestore(), "audit_logs/log_fake_002"), { log_id: "log_fake_002" })
    );

    const analyst = testEnv.authenticatedContext("analyst_log_002", { role: "analyst" });
    await assertFails(
      setDoc(doc(analyst.firestore(), "audit_logs/log_fake_003"), { log_id: "log_fake_003" })
    );

    const admin = testEnv.authenticatedContext("admin_log_002", { role: "admin" });
    await assertFails(
      setDoc(doc(admin.firestore(), "audit_logs/log_fake_004"), { log_id: "log_fake_004" })
    );

    const superAdmin = testEnv.authenticatedContext("super_admin_log_002", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "audit_logs/log_fake_005"), { log_id: "log_fake_005" })
    );
  });

  it("aucun rôle ne peut modifier directement un log d'audit existant (update), même super_admin", async () => {
    await seedLog("log_007");
    const superAdmin = testEnv.authenticatedContext("super_admin_log_003", { role: "super_admin" });
    await assertFails(
      updateDoc(doc(superAdmin.firestore(), "audit_logs/log_007"), { action: "tampered" })
    );
  });
});

// -----------------------------------------------------------------------
// DENY BY DEFAULT — collection inconnue
// -----------------------------------------------------------------------
describe("Security Rules — deny-by-default", () => {
  it("une collection non déclarée dans les règles est entièrement bloquée, même pour un super_admin", async () => {
    const superAdmin = testEnv.authenticatedContext("super_admin_001", { role: "super_admin" });
    await assertFails(
      setDoc(doc(superAdmin.firestore(), "some_undeclared_collection/doc_001"), { foo: "bar" })
    );
    await assertFails(getDoc(doc(superAdmin.firestore(), "some_undeclared_collection/doc_001")));
  });
});

// -----------------------------------------------------------------------
// BUG-V-01 (Phase 7, Bloc V) — delivery_requests/{missionId} : un client
// propriétaire ne doit JAMAIS pouvoir "annuler" (status -> 'cancelled') une
// mission déjà dans un état TERMINAL (completed/cancelled/disputed/refunded)
// via une écriture directe. Avant correctif, la règle ne vérifiait que le
// statut CIBLE, jamais le statut ACTUEL — un client pouvait rouvrir une
// mission 'completed' en 'cancelled' (financièrement déjà close, paiement
// capturé, ledger déjà écrit), ce qui aurait pu déclencher à tort le trigger
// onMissionEndedClearTracking (nettoyage tracking) sur une mission qui
// n'aurait jamais dû redevenir "active" côté état métier.
// -----------------------------------------------------------------------
describe("Security Rules — delivery_requests/{missionId} : BUG-V-01 (états terminaux protégés contre l'annulation cliente)", () => {
  afterEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await Promise.all(
        ["bugv01_completed", "bugv01_cancelled", "bugv01_disputed", "bugv01_refunded", "bugv01_assigned"].map((id) =>
          deleteDoc(doc(ctx.firestore(), `delivery_requests/${id}`))
        )
      );
    });
  });

  async function seed(id: string, status: string, customerId: string): Promise<void> {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `delivery_requests/${id}`), {
        customer_id: customerId,
        driver_id: "bugv01_driver_001",
        status,
        driver_offer_amount: 85,
        customer_total: 100,
        pricing_version: "V1",
      });
    });
  }

  it("un client ne peut PAS annuler une mission déjà 'completed'", async () => {
    await seed("bugv01_completed", "completed", "bugv01_customer_001");
    const customer = testEnv.authenticatedContext("bugv01_customer_001", { role: "customer" });
    await assertFails(
      updateDoc(doc(customer.firestore(), "delivery_requests/bugv01_completed"), {
        status: "cancelled",
        cancellation_reason: "tentative de réouverture",
      })
    );
  });

  it("un client ne peut PAS ré-annuler une mission déjà 'cancelled' (idempotence défensive)", async () => {
    await seed("bugv01_cancelled", "cancelled", "bugv01_customer_001");
    const customer = testEnv.authenticatedContext("bugv01_customer_001", { role: "customer" });
    await assertFails(
      updateDoc(doc(customer.firestore(), "delivery_requests/bugv01_cancelled"), {
        status: "cancelled",
        cancellation_reason: "second essai",
      })
    );
  });

  it("un client ne peut PAS annuler une mission 'disputed'", async () => {
    await seed("bugv01_disputed", "disputed", "bugv01_customer_001");
    const customer = testEnv.authenticatedContext("bugv01_customer_001", { role: "customer" });
    await assertFails(
      updateDoc(doc(customer.firestore(), "delivery_requests/bugv01_disputed"), {
        status: "cancelled",
        cancellation_reason: "tentative pendant litige",
      })
    );
  });

  it("un client ne peut PAS annuler une mission 'refunded'", async () => {
    await seed("bugv01_refunded", "refunded", "bugv01_customer_001");
    const customer = testEnv.authenticatedContext("bugv01_customer_001", { role: "customer" });
    await assertFails(
      updateDoc(doc(customer.firestore(), "delivery_requests/bugv01_refunded"), {
        status: "cancelled",
        cancellation_reason: "tentative post-remboursement",
      })
    );
  });

  it("[non-régression] un client PEUT toujours annuler une mission encore active ('assigned')", async () => {
    await seed("bugv01_assigned", "assigned", "bugv01_customer_001");
    const customer = testEnv.authenticatedContext("bugv01_customer_001", { role: "customer" });
    await assertSucceeds(
      updateDoc(doc(customer.firestore(), "delivery_requests/bugv01_assigned"), {
        status: "cancelled",
        cancellation_reason: "changement de plan",
      })
    );
  });
});
