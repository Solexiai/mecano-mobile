// 2026-11-09 : la notification d'offre annonce la part du chauffeur.
import { deliveryOfferPushCopyWithAmount, deliveryOfferPushCopy } from "../../src/lib/pushNotifications";
import { formatOfferAmountForPush } from "../../src/lib/offerCompensationPreview";

describe("notification d'offre avec montant", () => {
  test("format du montant par langue", () => {
    expect(formatOfferAmountForPush(62.4, "fr")).toBe("62,40 $");
    expect(formatOfferAmountForPush(62.4, "en")).toBe("$62.40");
    expect(formatOfferAmountForPush(100, "es")).toBe("100,00 $");
  });

  test("titre avec montant quand il est connu, texte générique sinon", () => {
    expect(deliveryOfferPushCopyWithAmount("fr", 62.4).title).toBe("Nouvelle livraison — 62,40 $ pour vous");
    expect(deliveryOfferPushCopyWithAmount("en", 62.4).title).toBe("New delivery — $62.40 for you");
    expect(deliveryOfferPushCopyWithAmount("es", 62.4).title).toContain("62,40 $");
    for (const bad of [null, undefined, 0, -3, Number.NaN]) {
      expect(deliveryOfferPushCopyWithAmount("fr", bad as number)).toEqual(deliveryOfferPushCopy("fr"));
    }
    expect(deliveryOfferPushCopyWithAmount("xx", 10)).toEqual(deliveryOfferPushCopyWithAmount("fr", 10));
  });
});
