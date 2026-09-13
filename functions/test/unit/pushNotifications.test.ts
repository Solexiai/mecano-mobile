import {
  customerMissionPushCopy,
  deliveryOfferPushCopy,
  normalizePushLocale,
} from "../../src/lib/pushNotifications";
import type { CustomerMissionPushType } from "../../src/lib/pushNotifications";

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


  test("provides localized customer mission-status copy for every notified status", () => {
    const statuses: CustomerMissionPushType[] = [
      "driver_assigned",
      "driver_to_pickup",
      "arrived_at_pickup",
      "picked_up",
      "in_transit",
      "arrived_at_dropoff",
      "completed",
      "cancelled",
    ];

    for (const status of statuses) {
      for (const locale of ["fr", "en", "es"] as const) {
        const copy = customerMissionPushCopy(status, locale);
        expect(copy.title.length).toBeGreaterThan(0);
        expect(copy.body.length).toBeGreaterThan(0);
        expect(copy.title).not.toMatch(/customer_id|driver_id|latitude|longitude/i);
        expect(copy.body).not.toMatch(/@|customer_id|driver_id|latitude|longitude/i);
      }
    }

    expect(customerMissionPushCopy("driver_assigned", "fr")).toEqual({
      title: "Chauffeur assigné",
      body: "Un chauffeur a été assigné à votre livraison.",
    });
    expect(customerMissionPushCopy("completed", "en").title).toBe("Delivery completed");
    expect(customerMissionPushCopy("cancelled", "es").title).toBe("Misión cancelada");
  });

  test("customer mission-status copy falls back to French for unsupported locale", () => {
    expect(customerMissionPushCopy("in_transit", "de")).toEqual(
      customerMissionPushCopy("in_transit", "fr")
    );
  });
});
