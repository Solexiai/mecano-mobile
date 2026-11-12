// Documents obligatoires d'un chauffeur (Daniel, 2026-11-12) : permis recto
// et verso, plus de pièce d'identité, ancien permis en une image accepté.
import { DRIVER_DOCUMENT_SLOTS, licenceSide, missingRequiredDocuments } from "../../src/lib/driverDocuments";

const doc = (type: string, file: string, status = "approved") => ({
  type,
  status,
  storage_bucket_path: `driver_documents/d1/${file}`,
});
const approved = (d: Record<string, unknown>) => d.status === "approved";

describe("driverDocuments", () => {
  it("reads the licence side from the file name", () => {
    expect(licenceSide(doc("drivers_licence", "drivers_licence_front_1.jpg"))).toBe("front");
    expect(licenceSide(doc("drivers_licence", "drivers_licence_back_1.pdf"))).toBe("back");
    expect(licenceSide(doc("drivers_licence", "drivers_licence_1.jpg"))).toBeNull();
    expect(licenceSide({ type: "drivers_licence" })).toBeNull();
  });

  it("complete file: front, back, registration, insurance — no identity needed", () => {
    expect(missingRequiredDocuments([
      doc("drivers_licence", "drivers_licence_front_1.jpg"),
      doc("drivers_licence", "drivers_licence_back_1.jpg"),
      doc("vehicle_registration", "vehicle_registration_1.jpg"),
      doc("insurance", "insurance_1.jpg"),
    ], approved)).toEqual([]);
  });

  it("names what is missing or not approved yet", () => {
    expect(missingRequiredDocuments([
      doc("drivers_licence", "drivers_licence_front_1.jpg"),
      doc("drivers_licence", "drivers_licence_back_1.jpg", "uploaded"),
      doc("insurance", "insurance_1.jpg"),
      doc("identity", "identity_1.jpg"),
    ], approved)).toEqual(["drivers_licence_back", "vehicle_registration"]);
    expect(missingRequiredDocuments([], approved)).toEqual([
      "drivers_licence_front", "drivers_licence_back", "vehicle_registration", "insurance",
    ]);
  });

  it("a licence sent before (one image) still counts for both sides", () => {
    expect(missingRequiredDocuments([
      doc("drivers_licence", "drivers_licence_1.jpg"),
      doc("vehicle_registration", "vehicle_registration_1.jpg"),
      doc("insurance", "insurance_1.jpg"),
    ], approved)).toEqual([]);
  });

  it("agents can only add known places", () => {
    expect(Object.keys(DRIVER_DOCUMENT_SLOTS)).toEqual([
      "drivers_licence_front", "drivers_licence_back", "vehicle_registration", "insurance",
      "vehicle_main_photo", "vehicle_rear_photo", "vehicle_plate_photo", "other",
    ]);
    expect(DRIVER_DOCUMENT_SLOTS.drivers_licence_back.type).toBe("drivers_licence");
    expect(Object.values(DRIVER_DOCUMENT_SLOTS).map((s) => s.type)).not.toContain("identity");
  });
});
