import {
  deliveryOfferPushCopy,
  normalizePushLocale,
} from "../../src/lib/pushNotifications";

describe("pushNotifications locale copy", () => {
  test("normalizes supported locales and falls back to French", () => {
    expect(normalizePushLocale("fr")).toBe("fr");
    expect(normalizePushLocale("en")).toBe("en");
    expect(normalizePushLocale("es")).toBe("es");
    expect(normalizePushLocale("de")).toBe("fr");
    expect(normalizePushLocale(undefined)).toBe("fr");
  });

  test("provides localized delivery-offer copy without exposing mission data", () => {
    expect(deliveryOfferPushCopy("fr").title).toBe("Nouvelle livraison disponible");
    expect(deliveryOfferPushCopy("en").title).toBe("New delivery available");
    expect(deliveryOfferPushCopy("es").title).toBe("Nueva entrega disponible");

    for (const locale of ["fr", "en", "es"] as const) {
      const copy = deliveryOfferPushCopy(locale);
      expect(copy.title.length).toBeGreaterThan(0);
      expect(copy.body.length).toBeGreaterThan(0);
      expect(copy.body).not.toMatch(/@|latitude|longitude|customer_id|driver_id/i);
    }
  });
});
