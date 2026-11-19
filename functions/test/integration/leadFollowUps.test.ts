// -----------------------------------------------------------------------------
// Relances des prospects (décision Daniel, 2026-11-17) : client avec un prix
// sans réservation (J+1, J+3), chauffeur à l'inscription inachevée,
// désabonnement et adresse postale obligatoire.
// -----------------------------------------------------------------------------
import { markDriverLead, runLeadFollowUps } from "../../src/functions/leadFollowUps";
import { validateDriverDocument } from "../../src/functions/validateDriverDocument";
import { requestDriverDocuments } from "../../src/functions/requestDriverDocuments";
import { admin, db } from "../../src/lib/admin";
import { EMAIL_SETTINGS_DOC, emailPreference, setFollowUpSubscription } from "../../src/lib/emailPreferences";
import { EmailSender, OutgoingEmail, setEmailSenderForTesting } from "../../src/lib/transactionalEmail";

class FakeSender implements EmailSender {
  sent: Array<{ email: OutgoingEmail; key: string }> = [];
  async send(email: OutgoingEmail, key: string) {
    this.sent.push({ email, key });
    return { id: `re_fake_${this.sent.length}` };
  }
}

const HOUR = 3600_000;
const POSTAL = "123 rue Principale, Granby (Québec) J2G 2V5";
const QUOTE = "lf_quote_001";
const MISSION = "lf_mission_001";
/** Aujourd'hui à midi, heure normale de l'Est : toujours dans les heures d'envoi. */
const NOON = Math.floor(Date.now() / (24 * HOUR)) * 24 * HOUR + 17 * HOUR;

let sender: FakeSender;
let customerUid = "";
let driverUid = "";

function ts(ms: number) {
  return admin.firestore.Timestamp.fromMillis(ms);
}

async function seedQuote(ageHours: number, overrides: Record<string, unknown> = {}, id = QUOTE): Promise<void> {
  await db.collection("delivery_quotes").doc(id).set({
    id, customer_id: customerUid, mission_id: null, is_consumed: false, status: "active", locale: "fr",
    customer_total_minor: 7243,
    stops: [
      { type: "pickup", address: { line1: "12 rue Principale", city: "Granby" } },
      { type: "dropoff", address: { line1: "45 boul. Leclerc", city: "Bromont" } },
    ],
    pricing_snapshot: { pre_assignment: { load: { items: [{ quantity: 1, label: "Divan" }] } } },
    created_at: ts(NOON - ageHours * HOUR),
    ...overrides,
  });
}

async function seedDriver(profile: Record<string, unknown>): Promise<void> {
  await db.collection("driver_profiles").doc(driverUid).set({ uid: driverUid, full_name: "Marc Caron", ...profile });
}

/** Relances faites pour les comptes de ce test (l'émulateur peut contenir d'autres données). */
async function run(nowMs = NOON): Promise<string[]> {
  const result = await runLeadFollowUps(nowMs);
  return [...result.customers, ...result.drivers].filter((k) => k.startsWith(customerUid) || k.startsWith(driverUid)).sort();
}

beforeAll(async () => {
  customerUid = (await admin.auth().createUser({ email: "lf.client@example.test", password: "synthetic-password" })).uid;
  driverUid = (await admin.auth().createUser({ email: "lf.driver@example.test", password: "synthetic-password" })).uid;
});

afterAll(async () => {
  for (const uid of [customerUid, driverUid]) await admin.auth().deleteUser(uid).catch(() => undefined);
});

beforeEach(async () => {
  sender = new FakeSender();
  setEmailSenderForTesting(sender);
  await db.doc(EMAIL_SETTINGS_DOC).set({ postal_address: POSTAL });
  await db.collection("users").doc(customerUid).set({ full_name: "Marie Tremblay", roles: ["customer"] });
});

afterEach(async () => {
  setEmailSenderForTesting(null);
  await db.doc(EMAIL_SETTINGS_DOC).delete();
  for (const id of [QUOTE, `${QUOTE}_b`]) await db.collection("delivery_quotes").doc(id).delete();
  await db.collection("delivery_requests").doc(MISSION).delete();
  await db.collection("driver_profiles").doc(driverUid).delete();
  await db.collection("driver_leads").doc(driverUid).delete();
  for (const id of ["lf_doc_front", "lf_doc_insurance"]) await db.collection("driver_documents").doc(id).delete();
  for (const uid of [customerUid, driverUid]) {
    const bell = await db.collection("users").doc(uid).collection("notifications").get();
    for (const n of bell.docs) await n.ref.delete();
    await db.collection("users").doc(uid).delete();
    await db.collection("email_preferences").doc(uid).delete();
    for (const name of ["email_log", "lead_followups"]) {
      const rows = await db.collection(name).where("user_id", "==", uid).get();
      for (const r of rows.docs) await r.ref.delete();
    }
  }
});

describe("Client : prix obtenu, pas de réservation", () => {
  it("rien le jour même ; J+1 une seule fois ; J+3 une seule fois ; puis plus rien", async () => {
    await seedQuote(5);
    expect(await run()).toEqual([]);

    await seedQuote(26);
    expect(await run()).toEqual([`${customerUid}__1`]);
    expect(await run()).toEqual([]);
    expect(sender.sent).toHaveLength(1);
    const first = sender.sent[0];
    expect(first.key).toBe(`quote_followup_1__${customerUid}__${QUOTE}`);
    expect(first.email.to).toBe("lf.client@example.test");
    expect(first.email.subject).toBe("Votre prix Movi-K : 72,43 $");
    expect(first.email.text).toContain("Bonjour Marie");
    expect(first.email.text).toContain(POSTAL);
    const { token } = await emailPreference(customerUid);
    expect(first.email.text).toContain(`emailUnsubscribe?u=${customerUid}&t=${token}`);
    expect(first.email.headers?.["List-Unsubscribe"]).toContain(token);

    // Le surlendemain de la relance 1 : 3 jours après la demande.
    expect(await run(NOON + 48 * HOUR)).toEqual([`${customerUid}__2`]);
    expect(await run(NOON + 49 * HOUR)).toEqual([]);
    expect(sender.sent.map((s) => s.email.subject)).toEqual([
      "Votre prix Movi-K : 72,43 $", "Toujours besoin de faire livrer ? — Movi-K",
    ]);
    const log = (await db.collection("email_log").doc(first.key).get()).data()!;
    expect(log).toMatchObject({ status: "sent", kind: "quote_followup_1", user_id: customerUid });
    expect(JSON.stringify(log)).not.toContain("lf.client@example.test");
  });

  it("un nouveau prix demandé le lendemain ne relance pas la série à zéro", async () => {
    await seedQuote(26);
    expect(await run()).toEqual([`${customerUid}__1`]);
    await seedQuote(1, { customer_total_minor: 8100 }, `${QUOTE}_b`);
    expect(await run(NOON + 24 * HOUR)).toEqual([]);
    // J+3 de la PREMIÈRE demande, avec le prix le plus récent.
    expect(await run(NOON + 48 * HOUR)).toEqual([`${customerUid}__2`]);
    expect(sender.sent[1].email.text).toContain("81,00 $");
  });

  it("il a réservé : aucune relance", async () => {
    await seedQuote(26);
    await db.collection("delivery_requests").doc(MISSION).set({ customer_id: customerUid, created_at: ts(NOON - 20 * HOUR) });
    expect(await run()).toEqual([]);
    expect(sender.sent).toHaveLength(0);
    const state = (await db.collection("lead_followups").doc(`customer__${customerUid}`).get()).data()!;
    expect(state.stopped_reason).toBe("booked");
  });

  it("prix utilisé pour réserver (devis consommé) : aucune relance", async () => {
    await seedQuote(26, { is_consumed: true, mission_id: MISSION });
    expect(await run()).toEqual([]);
    expect(sender.sent).toHaveLength(0);
  });

  it("désabonné : plus aucune relance ; un mauvais jeton ne désabonne personne", async () => {
    await seedQuote(26);
    const { token } = await emailPreference(customerUid);
    expect(await setFollowUpSubscription(customerUid, "x".repeat(token.length), true)).toBe(false);
    expect(await setFollowUpSubscription(customerUid, token, true)).toBe(true);
    expect(await run()).toEqual([]);
    expect(await run(NOON + 48 * HOUR)).toEqual([]);
    expect(sender.sent).toHaveLength(0);
  });

  it("personnel Movi-K et client effacé : jamais relancés", async () => {
    await seedQuote(26);
    await db.collection("users").doc(customerUid).set({ roles: ["customer", "super_admin"] });
    expect(await run()).toEqual([]);
    await db.collection("users").doc(customerUid).set({ deleted: true, roles: ["customer"] });
    expect(await run()).toEqual([]);
    expect(sender.sent).toHaveLength(0);
  });

  it("sans adresse postale, relances fermées ou hors des heures : rien ne part", async () => {
    await seedQuote(26);
    await db.doc(EMAIL_SETTINGS_DOC).delete();
    expect((await runLeadFollowUps(NOON)).status).toBe("not_ready");
    await db.doc(EMAIL_SETTINGS_DOC).set({ postal_address: POSTAL, followups_enabled: false });
    expect((await runLeadFollowUps(NOON)).status).toBe("not_ready");
    await db.doc(EMAIL_SETTINGS_DOC).set({ postal_address: POSTAL });
    expect((await runLeadFollowUps(NOON + 12 * HOUR)).status).toBe("outside_hours"); // minuit
    expect(sender.sent).toHaveLength(0);
  });
});

describe("Chauffeur : inscription inachevée", () => {
  it("dossier approuvé sans versements : annonce tout de suite, puis J+1 et J+3", async () => {
    await seedDriver({ status: "approved", approved_at: ts(NOON - 2 * HOUR), stripe_payouts_enabled: false });
    expect(await run()).toEqual([`${driverUid}__stripe__0`]);
    expect(await run()).toEqual([]);
    expect(await run(NOON + 24 * HOUR)).toEqual([`${driverUid}__stripe__1`]);
    expect(await run(NOON + 72 * HOUR)).toEqual([`${driverUid}__stripe__2`]);
    expect(await run(NOON + 96 * HOUR)).toEqual([]);
    expect(sender.sent.map((s) => s.email.subject)).toEqual([
      "Votre dossier est approuvé 🎉 — Movi-K",
      "Une dernière étape pour être payé — Movi-K",
      "Une dernière étape pour être payé — Movi-K",
    ]);
    expect(sender.sent[0].email.to).toBe("lf.driver@example.test");
    expect(sender.sent[0].email.text).toContain("Bonjour Marc");
  });

  it("versements activés : aucune relance", async () => {
    await seedDriver({ status: "approved", approved_at: ts(NOON - 30 * HOUR), stripe_payouts_enabled: true });
    expect(await run()).toEqual([]);
  });

  // 2026-11-19 (Daniel) : refuser un document met le dossier en suspens, prévient
  // le chauffeur (cloche) et envoie le courriel tout de suite.
  it("document refusé : dossier en suspens, cloche, courriel immédiat ; 2e refus dans l'heure = motif cumulé sans 2e courriel", async () => {
    const adminCall = (data: Record<string, unknown>) =>
      ({ data, auth: { uid: "admin_lf", token: { roles: ["admin"], role: "admin" } }, rawRequest: {}, acceptsStreaming: false } as any);
    await seedDriver({ status: "pending_review", submitted_for_review_at: ts(NOON - HOUR) });
    await db.collection("driver_documents").doc("lf_doc_front").set({
      driver_id: driverUid, type: "drivers_licence", status: "uploaded",
      storage_bucket_path: `driver_documents/${driverUid}/drivers_licence_front_1.jpg`,
    });
    await db.collection("driver_documents").doc("lf_doc_insurance").set({
      driver_id: driverUid, type: "insurance", status: "uploaded",
      storage_bucket_path: `driver_documents/${driverUid}/insurance_1.pdf`,
    });

    const first = await validateDriverDocument.run(adminCall({ documentId: "lf_doc_front", newStatus: "rejected", rejectionReason: "photo floue" }));
    expect(first).toMatchObject({ success: true, driverOnHold: true, emailSent: true });
    const profile = (await db.collection("driver_profiles").doc(driverUid).get()).data()!;
    expect(profile.status).toBe("documents_required");
    expect(profile.documents_required_reason).toBe("Permis de conduire (recto) : photo floue");
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].email.subject).toBe("Votre dossier est en suspens : document à fournir — Movi-K");
    expect(sender.sent[0].email.text).toContain("en suspens");
    expect(sender.sent[0].email.text).toContain("Permis de conduire (recto) : photo floue");
    const bell = await db.collection("users").doc(driverUid).collection("notifications").get();
    expect(bell.docs.map((d) => d.data().type)).toEqual(["driver_documents_required"]);

    const second = await validateDriverDocument.run(adminCall({ documentId: "lf_doc_insurance", newStatus: "replacement_required" }));
    expect(second).toMatchObject({ driverOnHold: true, emailSent: false });
    const merged = (await db.collection("driver_profiles").doc(driverUid).get()).data()!;
    expect(merged.documents_required_reason).toBe("Permis de conduire (recto) : photo floue\nPreuve d'assurance : à remplacer");
    expect(sender.sent).toHaveLength(1);

    // Le cron ne renvoie pas l'étape 0 ; la relance J+1 part le lendemain avec les deux motifs.
    expect(await run(NOON + HOUR)).toEqual([]);
    expect(await run(NOON + 26 * HOUR)).toEqual([`${driverUid}__documents__1`]);
    expect(sender.sent[1].email.text).toContain("Preuve d'assurance : à remplacer");
  });

  it("documents demandés à la main : courriel immédiat et cloche", async () => {
    const adminCall = (data: Record<string, unknown>) =>
      ({ data, auth: { uid: "admin_lf", token: { roles: ["admin"], role: "admin" } }, rawRequest: {}, acceptsStreaming: false } as any);
    await seedDriver({ status: "approved", approved_at: ts(NOON - 48 * HOUR), stripe_payouts_enabled: true });
    expect(await requestDriverDocuments.run(adminCall({ driverId: driverUid, reason: "Immatriculation expirée" })))
      .toMatchObject({ success: true, emailSent: true });
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].email.text).toContain("Immatriculation expirée");
    expect((await db.collection("users").doc(driverUid).collection("notifications").get()).size).toBe(1);
  });

  it("document demandé : relance J+1 avec le motif ; une nouvelle demande repart à zéro", async () => {
    await seedDriver({ status: "documents_required", documents_required_at: ts(NOON - 26 * HOUR), documents_required_reason: "Permis : verso illisible" });
    expect(await run()).toEqual([`${driverUid}__documents__1`]);
    expect(sender.sent[0].email.text).toContain("Permis : verso illisible");
    expect(await run()).toEqual([]);
    await seedDriver({ status: "documents_required", documents_required_at: ts(NOON - 25 * HOUR), documents_required_reason: "Immatriculation expirée" });
    expect(await run()).toEqual([`${driverUid}__documents__1`]);
    expect(sender.sent[1].email.text).toContain("Immatriculation expirée");
  });

  it("inscription inachevée (date ISO écrite par l'app) : relance J+1", async () => {
    await seedDriver({ status: "registration_incomplete", created_at: new Date(NOON - 30 * HOUR).toISOString() });
    expect(await run()).toEqual([`${driverUid}__profile__1`]);
    expect(sender.sent[0].email.subject).toBe("Terminez votre inscription de chauffeur — Movi-K");
  });

  it("dossier envoyé, versements pas activés : relances J+1 et J+3, puis annonce à l'approbation", async () => {
    await seedDriver({ status: "pending_review", submitted_for_review_at: ts(NOON - 2 * HOUR) });
    expect(await run()).toEqual([]); // il vient de voir l'écran : rien le jour même
    expect(await run(NOON + 24 * HOUR)).toEqual([`${driverUid}__stripe__1`]);
    expect(sender.sent[0].email.subject).toBe("Une dernière étape : activez vos versements — Movi-K");
    expect(sender.sent[0].email.text).toContain("Pendant que Movi-K vérifie votre dossier");
    expect(sender.sent[0].email.text).toContain("https://movi-k.com/fr/devenir-chauffeur/statut?");
    expect(await run(NOON + 72 * HOUR)).toEqual([`${driverUid}__stripe__2`]);
    // Approuvé ensuite, toujours sans versements : nouvelle série, annonce immédiate.
    await seedDriver({ status: "approved", approved_at: ts(NOON + 80 * HOUR), stripe_payouts_enabled: false });
    expect(await run(NOON + 96 * HOUR)).toEqual([`${driverUid}__stripe__0`]);
    expect(sender.sent[2].email.subject).toBe("Votre dossier est approuvé 🎉 — Movi-K");
  });

  it("dossier envoyé avec versements activés : rien", async () => {
    await seedDriver({ status: "pending_review", submitted_for_review_at: ts(NOON - 30 * HOUR), stripe_payouts_enabled: true });
    expect(await run()).toEqual([]);
  });

  it("compte créé au début de l'inscription, dossier jamais enregistré : relance J+1 ; rien dès que le dossier existe", async () => {
    await db.collection("users").doc(driverUid).set({ full_name: "Marc Caron", roles: ["customer"] });
    await db.collection("driver_leads").doc(driverUid).set({ user_id: driverUid, started_at: ts(NOON - 26 * HOUR) });
    expect(await run()).toEqual([`${driverUid}__profile__1`]);
    expect(sender.sent[0].email.subject).toBe("Terminez votre inscription de chauffeur — Movi-K");
    expect(sender.sent[0].email.text).toContain("Bonjour Marc");
    await seedDriver({ status: "pending_review", submitted_for_review_at: ts(NOON + 40 * HOUR), stripe_payouts_enabled: true });
    expect(await run(NOON + 48 * HOUR)).toEqual([]);
  });

  it("markDriverLead : compte connecté, noté une seule fois", async () => {
    const call = (uid?: string) =>
      ({ data: {}, auth: uid ? { uid, token: { roles: ["customer"], role: "customer" } } : undefined, rawRequest: {}, acceptsStreaming: false } as any);
    await expect(markDriverLead.run(call())).rejects.toMatchObject({ code: "unauthenticated" });
    expect(await markDriverLead.run(call(driverUid))).toEqual({ created: true, roles: ["customer", "driver"] });
    // Chauffeur dès les coordonnées (2026-11-19).
    expect((await db.collection("users").doc(driverUid).get()).data()).toMatchObject({
      roles: ["customer", "driver"],
      driver_signup: "started",
    });
    const first = (await db.collection("driver_leads").doc(driverUid).get()).data()!;
    expect(await markDriverLead.run(call(driverUid))).toEqual({ created: false, roles: ["customer", "driver"] });
    const second = (await db.collection("driver_leads").doc(driverUid).get()).data()!;
    expect(second.started_at.toMillis()).toBe(first.started_at.toMillis());
  });

  it("dossier vieux de plus de 5 jours ou refusé : rien", async () => {
    await seedDriver({ status: "rejected", created_at: ts(NOON - 30 * HOUR) });
    expect(await run()).toEqual([]);
    await seedDriver({ status: "registration_incomplete", created_at: ts(NOON - 200 * HOUR) });
    expect(await run()).toEqual([]);
  });
});
