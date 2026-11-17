// D'où vient chaque prospect (décision Daniel, 2026-11-17) : classement et tableau.
import { acquisitionLabel, buildAcquisitionReport, classifyAcquisition } from "../../src/lib/acquisition";

describe("classement de la première visite", () => {
  const channel = (raw: Record<string, unknown>) => classifyAcquisition(raw).channel;

  it("publicités : Facebook payant, Google Ads (gclid), Bing Ads", () => {
    expect(channel({ source: "facebook", medium: "cpc", campaign: "chauffeurs_nov" })).toBe("paid_social");
    expect(channel({ source: "Instagram", medium: "paid" })).toBe("paid_social");
    expect(channel({ clickId: "gclid" })).toBe("paid_search");
    expect(channel({ source: "google", medium: "cpc" })).toBe("paid_search");
    expect(channel({ clickId: "msclkid" })).toBe("paid_search");
  });

  it("fbclid sans utm : Facebook, mais pas compté comme publicité", () => {
    const a = classifyAcquisition({ clickId: "fbclid", referrer: "https://l.facebook.com/" });
    expect(a.channel).toBe("organic_social");
    expect(a.source).toBe("facebook");
  });

  it("recherche, réseaux sociaux, autre site, direct, application", () => {
    expect(channel({ referrer: "https://www.google.com/" })).toBe("organic_search");
    expect(channel({ referrer: "https://www.bing.com/search?q=x" })).toBe("organic_search");
    expect(channel({ referrer: "https://m.facebook.com/" })).toBe("organic_social");
    expect(channel({ referrer: "https://www.pagesjaunes.ca/x" })).toBe("referral");
    expect(channel({})).toBe("direct");
    expect(channel({ referrer: "https://www.movi-k.com/fr" })).toBe("direct");
    expect(channel({ platform: "android" })).toBe("app");
  });

  it("courriels de relance et autres campagnes", () => {
    expect(channel({ source: "movik", medium: "email", campaign: "relance_prix_j1" })).toBe("email");
    expect(channel({ source: "depliant", medium: "qr" })).toBe("campaign");
    // « digital » ne contient pas le réseau « ig ».
    expect(channel({ source: "digital" })).toBe("campaign");
  });

  it("nettoie les valeurs : pas de balises, longueur bornée, référent réduit au domaine", () => {
    const a = classifyAcquisition({
      source: "<script>fb</script>", campaign: "x".repeat(500), referrer: "https://www.kijiji.ca/v-annonce/123?x=1",
      landingPath: "/fr/livraison/demande", firstSeenAtMs: 1700000000000, unknown: "ignoré",
    });
    expect(a.source).toBe("scriptfb/script");
    expect(a.campaign).toHaveLength(100);
    expect(a.referrer_host).toBe("kijiji.ca");
    expect(a.landing_path).toBe("/fr/livraison/demande");
    expect(a.first_seen_at_ms).toBe(1700000000000);
    expect(classifyAcquisition(null).channel).toBe("direct");
  });

  it("libellé du tableau", () => {
    expect(acquisitionLabel(classifyAcquisition({ source: "facebook", medium: "cpc", campaign: "nov" }))).toBe("facebook / cpc / nov");
    expect(acquisitionLabel(classifyAcquisition({ referrer: "https://www.google.com/" }))).toBe("google.com");
    expect(acquisitionLabel(classifyAcquisition({}))).toBe("");
  });
});

describe("tableau source → prix → réservation", () => {
  it("compte chaque personne une fois ; les clients sans source vont dans « unknown »", () => {
    const fb = classifyAcquisition({ source: "facebook", medium: "cpc", campaign: "nov" });
    const google = classifyAcquisition({ referrer: "https://www.google.com/" });
    const rows = buildAcquisitionReport({
      sources: new Map([["a", fb], ["b", fb], ["c", google]]),
      newAccountIds: ["a", "b", "c"],
      pricedCustomerIds: ["a", "a", "b", "c", "vieux"],
      bookedCustomerIds: ["c", "vieux"],
      driverIds: ["b"],
    });
    expect(rows).toEqual([
      { channel: "organic_search", label: "google.com", accounts: 1, priced: 1, booked: 1, drivers: 0 },
      { channel: "unknown", label: "", accounts: 0, priced: 1, booked: 1, drivers: 0 },
      { channel: "paid_social", label: "facebook / cpc / nov", accounts: 2, priced: 2, booked: 0, drivers: 1 },
    ]);
  });
});
