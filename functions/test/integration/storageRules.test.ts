// ---------------------------------------------------------------------------
// Tests d'intégration — Firebase Storage Security Rules (Phase 3, point 17).
//
// Couvre les 3 espaces de noms Storage de l'app (voir storage.rules) :
//   1. driver_documents/{driverId}/{fileName}
//   2. profile_photos/{userId}/{fileName}
//   3. delivery_proofs/{missionId}/{fileName}
//
// Nécessite les émulateurs Firestore + Auth + Storage démarrés (voir
// package.json script "test:integration"). Les règles delivery_proofs
// utilisent `firestore.get()` pour vérifier la propriété d'une mission —
// les métadonnées Firestore correspondantes sont donc pré-chargées via
// `withSecurityRulesDisabled()` avant chaque scénario qui en a besoin.
// ---------------------------------------------------------------------------

import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { ref, uploadBytes, deleteObject, getBytes } from "firebase/storage";
import { doc, setDoc } from "firebase/firestore";
import { createTestEnvWithStorage } from "./setup";

let testEnv: RulesTestEnvironment;

const smallImage = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]); // en-tête JPEG minimal

async function seedMission(
  missionId: string,
  data: { customer_id: string; driver_id: string | null; status?: string }
) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `delivery_requests/${missionId}`), {
      status: "picked_up",
      ...data,
    });
  });
}

// Un seul RulesTestEnvironment partagé par TOUT le fichier (Firestore +
// Storage emulators restent actifs pendant l'ensemble des describe blocks).
// 🔒 IMPORTANT : beforeAll/afterAll doivent être déclarés au niveau racine
// du fichier, PAS à l'intérieur d'un describe() individuel — sinon
// testEnv.cleanup() s'exécute après le premier describe et détruit
// l'environnement pour tous les describe suivants (bug constaté lors de la
// première version de ce fichier : 7/11 tests échouaient avec "This
// RulesTestEnvironment has already been cleaned up").
beforeAll(async () => {
  testEnv = await createTestEnvWithStorage();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("Storage Rules — driver_documents/{driverId}/{fileName}", () => {
  // 1. Le chauffeur propriétaire peut téléverser son propre document.
  it("1. le chauffeur propriétaire peut téléverser son propre document (create)", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_owner", { role: "driver" });
    const fileRef = ref(driver.storage(), "driver_documents/driver_doc_owner/licence.jpg");
    await assertSucceeds(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
  });

  // 2. Un autre chauffeur ne peut PAS téléverser dans le dossier d'un autre.
  it("2. un autre chauffeur ne peut PAS téléverser dans le dossier d'un autre chauffeur", async () => {
    const intruder = testEnv.authenticatedContext("driver_doc_intruder", { role: "driver" });
    const fileRef = ref(intruder.storage(), "driver_documents/driver_doc_owner/fake.jpg");
    await assertFails(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
  });

  // 3. Immutabilité : le propriétaire ne peut pas écraser un document déjà
  //    téléversé. Dans Cloud Storage, un second upload sur le MÊME chemin
  //    est catégorisé `create` (pas `update`) — la règle `create` exige donc
  //    `resource == null` pour bloquer ce cas.
  it("3. le chauffeur propriétaire ne peut PAS écraser (ré-upload) un document déjà téléversé", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_immutable", { role: "driver" });
    const fileRef = ref(driver.storage(), "driver_documents/driver_doc_immutable/permis.jpg");
    await assertSucceeds(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
  });

  // 4. Lecture : propriétaire + analyst peuvent lire ; un inconnu ne peut pas.
  it("4. lecture : le propriétaire et un analyst peuvent lire, un chauffeur tiers ne peut pas", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_readtest", { role: "driver" });
    const fileRef = ref(driver.storage(), "driver_documents/driver_doc_readtest/assurance.jpg");
    await uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" });

    await assertSucceeds(getBytes(ref(driver.storage(), fileRef.fullPath)));

    const analyst = testEnv.authenticatedContext("analyst_doc_read", { role: "analyst" });
    await assertSucceeds(getBytes(ref(analyst.storage(), fileRef.fullPath)));

    const stranger = testEnv.authenticatedContext("driver_doc_stranger", { role: "driver" });
    await assertFails(getBytes(ref(stranger.storage(), fileRef.fullPath)));
  });

  // 5. Type de fichier invalide (ex: exécutable) rejeté même pour le propriétaire.
  it("5. un type de fichier non autorisé (ex: text/plain) est rejeté même pour le propriétaire", async () => {
    const driver = testEnv.authenticatedContext("driver_doc_badtype", { role: "driver" });
    const fileRef = ref(driver.storage(), "driver_documents/driver_doc_badtype/malware.exe");
    await assertFails(
      uploadBytes(fileRef, smallImage, { contentType: "application/x-msdownload" })
    );
  });
});

describe("Storage Rules — profile_photos/{userId}/{fileName}", () => {
  // 6. Le propriétaire peut téléverser/mettre à jour son propre avatar.
  it("6. l'utilisateur propriétaire peut téléverser/remplacer son propre avatar", async () => {
    const user = testEnv.authenticatedContext("user_avatar_owner", { role: "customer" });
    const fileRef = ref(user.storage(), "profile_photos/user_avatar_owner/avatar.jpg");
    await assertSucceeds(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
    // Contrairement à driver_documents, l'avatar N'EST PAS immuable : un
    // second upload (remplacement) doit réussir.
    await assertSucceeds(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
  });

  // 7. Lecture publique : même un utilisateur non authentifié peut lire un avatar.
  it("7. la lecture d'un avatar est publique, y compris sans authentification", async () => {
    const owner = testEnv.authenticatedContext("user_avatar_public", { role: "customer" });
    const fileRef = ref(owner.storage(), "profile_photos/user_avatar_public/avatar.jpg");
    await uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" });

    const anon = testEnv.unauthenticatedContext();
    await assertSucceeds(getBytes(ref(anon.storage(), fileRef.fullPath)));

    // Mais un tiers authentifié ne peut PAS écrire/supprimer l'avatar d'un autre.
    const intruder = testEnv.authenticatedContext("user_avatar_intruder", { role: "customer" });
    await assertFails(
      uploadBytes(ref(intruder.storage(), fileRef.fullPath), smallImage, {
        contentType: "image/jpeg",
      })
    );
    await assertFails(deleteObject(ref(intruder.storage(), fileRef.fullPath)));
  });
});

describe("Storage Rules — delivery_proofs/{missionId}/{fileName}", () => {
  // 8. Seul le chauffeur assigné à la mission peut uploader la preuve de livraison.
  it("8. seul le chauffeur assigné à la mission peut uploader la preuve de livraison", async () => {
    await seedMission("mission_proof_ok", {
      customer_id: "customer_proof_ok",
      driver_id: "driver_proof_ok",
    });

    const assignedDriver = testEnv.authenticatedContext("driver_proof_ok", { role: "driver" });
    const fileRef = ref(assignedDriver.storage(), "delivery_proofs/mission_proof_ok/pod.jpg");
    await assertSucceeds(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));

    // Un chauffeur non assigné à CETTE mission ne peut pas uploader dessus.
    const otherDriver = testEnv.authenticatedContext("driver_proof_other", { role: "driver" });
    await assertFails(
      uploadBytes(
        ref(otherDriver.storage(), "delivery_proofs/mission_proof_ok/fake_pod.jpg"),
        smallImage,
        { contentType: "image/jpeg" }
      )
    );
  });

  // 9. Lecture : client et chauffeur de la mission + analyst peuvent lire ; un tiers ne peut pas.
  it("9. lecture de la preuve : client, chauffeur assigné et analyst peuvent lire ; un tiers ne peut pas", async () => {
    await seedMission("mission_proof_read", {
      customer_id: "customer_proof_read",
      driver_id: "driver_proof_read",
    });

    const driver = testEnv.authenticatedContext("driver_proof_read", { role: "driver" });
    const fileRef = ref(driver.storage(), "delivery_proofs/mission_proof_read/pod.jpg");
    await uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" });

    await assertSucceeds(getBytes(ref(driver.storage(), fileRef.fullPath)));

    const customer = testEnv.authenticatedContext("customer_proof_read", { role: "customer" });
    await assertSucceeds(getBytes(ref(customer.storage(), fileRef.fullPath)));

    const analyst = testEnv.authenticatedContext("analyst_proof_read", { role: "analyst" });
    await assertSucceeds(getBytes(ref(analyst.storage(), fileRef.fullPath)));

    const stranger = testEnv.authenticatedContext("customer_proof_stranger", { role: "customer" });
    await assertFails(getBytes(ref(stranger.storage(), fileRef.fullPath)));
  });

  // 9bis. La preuve de livraison est immuable (pas de remplacement/suppression).
  //       Le ré-upload est catégorisé `create` par Cloud Storage (voir note
  //       ci-dessus sur driver_documents) ; bloqué via `resource == null`.
  it("9bis. la preuve de livraison ne peut être ni remplacée ni supprimée, même par le chauffeur assigné", async () => {
    await seedMission("mission_proof_immutable", {
      customer_id: "customer_proof_immutable",
      driver_id: "driver_proof_immutable",
    });

    const driver = testEnv.authenticatedContext("driver_proof_immutable", { role: "driver" });
    const fileRef = ref(driver.storage(), "delivery_proofs/mission_proof_immutable/pod.jpg");
    await uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" });

    await assertFails(uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" }));
    await assertFails(deleteObject(fileRef));
  });

  // 10. Un utilisateur NON authentifié ne peut ni uploader ni lire la preuve.
  it("10. un utilisateur NON authentifié ne peut PAS uploader la preuve de livraison", async () => {
    await seedMission("mission_proof_unauth", {
      customer_id: "customer_proof_unauth",
      driver_id: "driver_proof_unauth",
    });
    const anon = testEnv.unauthenticatedContext();
    await assertFails(
      uploadBytes(ref(anon.storage(), "delivery_proofs/mission_proof_unauth/pod.jpg"), smallImage, {
        contentType: "image/jpeg",
      })
    );
    await assertFails(getBytes(ref(anon.storage(), "delivery_proofs/mission_proof_unauth/pod.jpg")));
  });

  // 11. Un type de fichier non autorisé (ex: text/plain) est rejeté même
  //     pour le chauffeur assigné.
  it("11. un type de fichier non autorisé (ex: text/plain) est rejeté même pour le chauffeur assigné", async () => {
    await seedMission("mission_proof_badtype", {
      customer_id: "customer_proof_badtype",
      driver_id: "driver_proof_badtype",
    });
    const driver = testEnv.authenticatedContext("driver_proof_badtype", { role: "driver" });
    await assertFails(
      uploadBytes(
        ref(driver.storage(), "delivery_proofs/mission_proof_badtype/notes.txt"),
        new Uint8Array([1, 2, 3]),
        { contentType: "text/plain" }
      )
    );
  });

  // 12. Le CLIENT (customer) de la mission ne peut PAS uploader la preuve —
  //     seul le chauffeur assigné le peut (voir test 8).
  it("12. le client de la mission ne peut PAS uploader la preuve de livraison", async () => {
    await seedMission("mission_proof_customer_upload", {
      customer_id: "customer_proof_uploader",
      driver_id: "driver_proof_customer_upload",
    });
    const customer = testEnv.authenticatedContext("customer_proof_uploader", { role: "customer" });
    await assertFails(
      uploadBytes(
        ref(customer.storage(), "delivery_proofs/mission_proof_customer_upload/pod.jpg"),
        smallImage,
        { contentType: "image/jpeg" }
      )
    );
  });

  // 13. Le CLIENT propriétaire de la mission peut lire la preuve une fois
  //     téléversée (déjà couvert par le test 9, réaffirmé explicitement ici
  //     avec un scénario dédié pour la clarté de la couverture demandée).
  it("13. le client propriétaire de la mission peut lire la preuve de livraison une fois téléversée", async () => {
    await seedMission("mission_proof_owner_read", {
      customer_id: "customer_proof_owner",
      driver_id: "driver_proof_owner_read",
    });
    const driver = testEnv.authenticatedContext("driver_proof_owner_read", { role: "driver" });
    const fileRef = ref(driver.storage(), "delivery_proofs/mission_proof_owner_read/pod.jpg");
    await uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" });

    const owner = testEnv.authenticatedContext("customer_proof_owner", { role: "customer" });
    await assertSucceeds(getBytes(ref(owner.storage(), fileRef.fullPath)));
  });

  // 14. Un AUTRE client (n'ayant aucun lien avec cette mission) ne peut PAS
  //     lire la preuve de livraison (accès croisé bloqué).
  it("14. un autre client sans lien avec la mission ne peut PAS lire la preuve de livraison", async () => {
    await seedMission("mission_proof_other_customer", {
      customer_id: "customer_proof_real_owner",
      driver_id: "driver_proof_other_customer",
    });
    const driver = testEnv.authenticatedContext("driver_proof_other_customer", { role: "driver" });
    const fileRef = ref(driver.storage(), "delivery_proofs/mission_proof_other_customer/pod.jpg");
    await uploadBytes(fileRef, smallImage, { contentType: "image/jpeg" });

    const otherCustomer = testEnv.authenticatedContext("customer_proof_intruder", { role: "customer" });
    await assertFails(getBytes(ref(otherCustomer.storage(), fileRef.fullPath)));
  });
});

describe("Storage Rules — deny-by-default", () => {
  it("un chemin non déclaré dans storage.rules est entièrement bloqué, même pour un super_admin authentifié", async () => {
    const superAdmin = testEnv.authenticatedContext("super_admin_storage", { role: "super_admin" });
    const fileRef = ref(superAdmin.storage(), "some_undeclared_path/file.txt");
    await assertFails(
      uploadBytes(fileRef, new Uint8Array([1]), { contentType: "text/plain" })
    );
    await assertFails(getBytes(fileRef));
  });
});
