// Relances des prospects (décision Daniel, 2026-11-17) : calendrier J+1 / J+3 et contenu.
jest.mock("../../src/lib/admin", () => ({ admin: {}, db: {} }));
import {
  bookingRequestUrl,
  driverFollowUpEmail,
  driverStageUrl,
  followUpMillis,
  followUpStepDue,
  quoteFollowUpEmail,
  withinFollowUpSendingHours,
} from "../../src/lib/followUpEmails";
import { followUpsReady, parseEmailSettings } from "../../src/lib/emailPreferences";

const HOUR = 3600_000;
const T0 = Date.parse("2026-11-17T17:00:00.000Z"); // mardi midi à Montréal
const legal = { postalAddress: "123 rue Principale, Granby (Québec) J2G 2V5", unsubscribeUrl: "https://example.test/u?u=abc&t=tok" };
const quote = {
  customer_total_minor: 7243,
  locale: "fr",
  stops: [
    { type: "pickup", address: { line1: "12 rue Principale", city: "Granby" } },
    { type: "dropoff", address: { line1: "45 boul. Leclerc", city: "Bromont" } },
  ],
  pricing_snapshot: { pre_assignment: { load: { items: [{ quantity: 1, label: "Divan" }, { quantity: 2, label: "Chaise <b>pliante</b>" }] } } },
};

describe("calendrier des relances", () => {
  const due = (ageHours: number, sent: Record<number, number> = {}, immediate = false) =>
    followUpStepDue({ anchorMs: T0 - ageHours * HOUR, nowMs: T0, sent, immediate });

  it("rien avant 24 h ; relance 1 de 24 h à 72 h ; relance 2 de 72 h à 5 jours ; puis plus rien", () => {
    expect(due(2)).toBeNull();
    expect(due(23.9)).toBeNull();
    expect(due(24)).toBe(1);
    expect(due(71)).toBe(1);
    expect(due(72)).toBe(2);
    expect(due(119)).toBe(2);
    expect(due(120)).toBeNull();
    expect(due(400)).toBeNull();
  });

  it("chaque relance une seule fois, et la 2 au moins 24 h après la 1", () => {
    expect(due(30, { 1: T0 - 2 * HOUR })).toBeNull();
    expect(due(73, { 1: T0 - 2 * HOUR })).toBeNull();
    expect(due(73, { 1: T0 - 30 * HOUR })).toBe(2);
    expect(due(100, { 1: T0 - 60 * HOUR, 2: T0 - 20 * HOUR })).toBeNull();
    // Après la relance 2, la relance 1 ne repart jamais.
    expect(due(40, { 2: T0 - HOUR })).toBeNull();
  });

  it("étape 0 (approbation chauffeur) : seulement si demandée, dans les 24 premières heures, une fois", () => {
    expect(due(1, {}, true)).toBe(0);
    expect(due(1)).toBeNull();
    expect(due(1, { 0: T0 - HOUR }, true)).toBeNull();
    expect(due(30, { 0: T0 - 29 * HOUR }, true)).toBe(1);
  });

  it("date absente ou dans le futur : rien", () => {
    expect(followUpStepDue({ anchorMs: null, nowMs: T0, sent: {} })).toBeNull();
    expect(followUpStepDue({ anchorMs: T0 + HOUR, nowMs: T0, sent: {} })).toBeNull();
  });

  it("envois de 9 h à 20 h, heure du Québec", () => {
    expect(withinFollowUpSendingHours(Date.parse("2026-11-17T13:59:00.000Z"))).toBe(false); // 8 h 59
    expect(withinFollowUpSendingHours(Date.parse("2026-11-17T14:00:00.000Z"))).toBe(true); // 9 h
    expect(withinFollowUpSendingHours(Date.parse("2026-11-18T00:59:00.000Z"))).toBe(true); // 19 h 59
    expect(withinFollowUpSendingHours(Date.parse("2026-11-18T01:00:00.000Z"))).toBe(false); // 20 h
  });

  it("lit un Timestamp, une date ISO ou un nombre", () => {
    expect(followUpMillis({ toMillis: () => 42 })).toBe(42);
    expect(followUpMillis("2026-11-17T17:00:00.000Z")).toBe(T0);
    expect(followUpMillis(7)).toBe(7);
    expect(followUpMillis("pas une date")).toBeNull();
    expect(followUpMillis(null)).toBeNull();
  });
});

describe("courriel de relance du client", () => {
  it("J+1 : prix, trajet, objets, bouton, adresse postale et désabonnement", () => {
    const email = quoteFollowUpEmail({ quote, step: 1, locale: "fr", customerName: "Marie Tremblay", legal });
    expect(email.category).toBe("quote_followup_1");
    expect(email.subject).toBe("Votre prix Movi-K : 72,43 $");
    for (const part of ["Bonjour Marie, hier", "72,43 $", "12 rue Principale, Granby", "45 boul. Leclerc, Bromont",
      "1 × Divan, 2 × Chaise", bookingRequestUrl("fr", "relance_prix_j1"), legal.postalAddress, legal.unsubscribeUrl,
      "Me désabonner de ces rappels", "demandé un prix sur movi-k.com"]) {
      expect(email.text).toContain(part);
    }
    expect(email.headers).toEqual({
      "List-Unsubscribe": `<${legal.unsubscribeUrl}>`,
      "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
    });
    // Contenu saisi par le client échappé ; lien de désabonnement cliquable.
    expect(email.html).not.toContain("<b>pliante");
    expect(email.html).toContain("https://example.test/u?u=abc&amp;t=tok");
    expect(email.html).toContain("https://movi-k.com/fr/livraison/demande?utm_source=movik&amp;utm_medium=email&amp;utm_campaign=relance_prix_j1");
  });

  it("J+3 : dernier rappel, sans rabais ; sans nom, la phrase commence par une majuscule", () => {
    const email = quoteFollowUpEmail({ quote: { ...quote, locale: "en" }, step: 2, locale: "en", legal });
    expect(email.category).toBe("quote_followup_2");
    expect(email.subject).toBe("Still need it delivered? — Movi-K");
    expect(email.text).toContain("Your delivery request is still open");
    expect(email.text).toContain("This is our last reminder for this request.");
    expect(email.text).toContain("$72.43");
    expect(email.text).toContain(bookingRequestUrl("en", "relance_prix_j3"));
    expect(email.text.toLowerCase()).not.toContain("discount");
  });

  it("prix absent : aucun montant inventé", () => {
    const email = quoteFollowUpEmail({ quote: { stops: [] }, step: 1, locale: "fr", legal });
    expect(email.subject).toBe("Votre prix Movi-K vous attend");
    expect(email.text).not.toContain("0,00 $");
  });
});

describe("courriel de relance du chauffeur", () => {
  it("inscription inachevée : ce qu'il gagne et le lien d'inscription", () => {
    const email = driverFollowUpEmail({ stage: "profile", step: 1, locale: "fr", driverName: "Marc Caron", legal });
    expect(email.category).toBe("driver_followup_profile_1");
    expect(email.subject).toBe("Terminez votre inscription de chauffeur — Movi-K");
    for (const part of ["Bonjour Marc,", "80 $ à 120 $ pour 2 à 4 articles", "100 % des pourboires",
      driverStageUrl("profile", "fr", "relance_chauffeur_profile_j1"), legal.postalAddress, legal.unsubscribeUrl]) {
      expect(email.text).toContain(part);
    }
  });

  it("document demandé : le motif écrit par Movi-K est repris", () => {
    const email = driverFollowUpEmail({
      stage: "documents", step: 2, locale: "fr", documentsReason: "Permis : verso illisible", legal,
    });
    expect(email.text).toContain("Ce qu'il manque : Permis : verso illisible");
    expect(email.text).toContain("C'est notre dernier rappel.");
    expect(email.text).toContain("https://movi-k.com/fr/devenir-chauffeur/statut?");
  });

  it("Stripe : annonce de l'approbation (étape 0), puis rappels", () => {
    const approved = driverFollowUpEmail({ stage: "stripe", step: 0, locale: "fr", driverName: "Marc", legal });
    expect(approved.subject).toBe("Votre dossier est approuvé 🎉 — Movi-K");
    expect(approved.text).toContain("activer vos versements avec Stripe");
    expect(approved.text).toContain("https://movi-k.com/fr/fournisseur/tableau-de-bord?");
    const later = driverFollowUpEmail({ stage: "stripe", step: 1, locale: "en", legal });
    expect(later.subject).toBe("One last step to get paid — Movi-K");
    expect(later.category).toBe("driver_followup_stripe_1");
  });
});

describe("réglages des relances", () => {
  it("sans adresse postale, ou interrupteur fermé : aucune relance", () => {
    expect(followUpsReady(parseEmailSettings(undefined))).toBe(false);
    expect(followUpsReady(parseEmailSettings({ postal_address: "  " }))).toBe(false);
    expect(followUpsReady(parseEmailSettings({ postal_address: legal.postalAddress }))).toBe(true);
    expect(followUpsReady(parseEmailSettings({ postal_address: legal.postalAddress, followups_enabled: false }))).toBe(false);
  });
});
