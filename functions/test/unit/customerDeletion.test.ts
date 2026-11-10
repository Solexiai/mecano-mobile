// Effacer un client et liste « Accepte les offres » (Daniel, 2026-11-10) — calculs purs.
import {
  anonymizedUserDoc,
  deletionBlockers,
  deletionMode,
  latestMarketingOptIns,
} from "../../src/lib/customerDeletion";

const base = {
  actorUid: "boss",
  targetUid: "client",
  roles: ["customer"],
  hasDriverProfile: false,
  missions: [] as Record<string, unknown>[],
  payments: [] as Record<string, unknown>[],
};

describe("customerDeletion", () => {
  it("un client terminé, sans dette ni litige, peut être effacé", () => {
    expect(deletionBlockers({
      ...base,
      missions: [{ status: "completed" }, { status: "cancelled" }],
      payments: [{ status: "captured" }, { status: "refunded" }, { status: "cancelled" }],
    })).toEqual([]);
  });

  it("bloque : soi-même, personnel, chauffeur", () => {
    expect(deletionBlockers({ ...base, targetUid: "boss" })[0]).toMatch(/propre compte/);
    expect(deletionBlockers({ ...base, roles: ["customer", "admin"] })[0]).toMatch(/personnel/);
    expect(deletionBlockers({ ...base, hasDriverProfile: true })[0]).toMatch(/chauffeur/);
    expect(deletionBlockers({ ...base, roles: ["customer", "driver"] })[0]).toMatch(/chauffeur/);
  });

  it("bloque : livraison en cours, solde dû, litige", () => {
    expect(deletionBlockers({ ...base, missions: [{ status: "in_transit" }, { status: "assigned" }] }))
      .toEqual(["2 livraison(s) en cours : terminez-les ou annulez-les d'abord."]);
    expect(deletionBlockers({ ...base, payments: [{ status: "capture_failed" }] })[0]).toMatch(/pas réglé/);
    expect(deletionBlockers({ ...base, payments: [{ status: "authorized" }] })[0]).toMatch(/pas réglé/);
    expect(deletionBlockers({
      ...base, payments: [{ status: "failed", failure_code: "capture_abandoned_after_retries" }],
    })[0]).toMatch(/pas réglé/);
    expect(deletionBlockers({ ...base, payments: [{ status: "failed", failure_code: "card_declined" }] })).toEqual([]);
    expect(deletionBlockers({ ...base, missions: [{ status: "disputed" }] })).toEqual([
      "1 litige(s) ouvert(s) : réglez-les d'abord.",
    ]);
    expect(deletionBlockers({ ...base, payments: [{ status: "chargeback" }] })[0]).toMatch(/litige/);
  });

  it("historique → anonymiser ; rien réservé ni payé → tout effacer", () => {
    expect(deletionMode([], [])).toBe("erase");
    expect(deletionMode([{ status: "quoted" }, { status: "draft" }], [])).toBe("erase");
    expect(deletionMode([{ status: "cancelled" }], [])).toBe("anonymize");
    expect(deletionMode([], [{ status: "cancelled" }])).toBe("anonymize");
  });

  it("profil anonymisé : aucune donnée personnelle ne survit", () => {
    const doc = anonymizedUserDoc(
      {
        full_name: "Marie Tremblay", email: "marie@example.test", phone: "450 555-1234",
        saved_addresses: { home: { line1: "12 rue Principale" } }, booking_contacts: { pickup_phone: "450" },
        created_at: "2026-11-01T15:00:00.000Z", internal_tester: true,
      },
      "client", "boss", "NOW"
    );
    expect(doc).toEqual({
      uid: "client", roles: ["customer"], full_name: "Client supprimé", deleted: true,
      deleted_at: "NOW", deleted_by: "boss", is_disabled: true, created_at: "2026-11-01T15:00:00.000Z",
    });
    expect(JSON.stringify(doc)).not.toMatch(/marie|555|Principale/i);
  });

  it("offres : seule la DERNIÈRE réservation de chaque client compte", () => {
    expect(latestMarketingOptIns([
      { customerId: "a", createdAt: "2026-11-01T10:00:00Z", optIn: true },
      { customerId: "b", createdAt: "2026-11-01T10:00:00Z", optIn: true },
      { customerId: "b", createdAt: "2026-11-05T10:00:00Z", optIn: false },
      { customerId: "c", createdAt: "2026-11-01T10:00:00Z", optIn: false },
      { customerId: "c", createdAt: "2026-11-06T10:00:00Z", optIn: true },
      { customerId: null, createdAt: null, optIn: true },
    ])).toEqual(["a", "c"]);
  });
});
