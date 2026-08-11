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
