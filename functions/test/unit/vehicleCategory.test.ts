import {
  dispatchCategory,
  driverServesMissionCategory,
  normalizeVehicleCategory,
  resolveConfiguredVehicleCategory,
  supportsVehicleCategory,
} from "../../src/lib/vehicleCategory";

describe("vehicle category compatibility", () => {
  it("normalise camelCase et snake_case vers la même valeur canonique", () => {
    expect(normalizeVehicleCategory("cargoVan")).toBe("cargo_van");
    expect(normalizeVehicleCategory("cargo_van")).toBe("cargo_van");
    expect(normalizeVehicleCategory("pickupTruck")).toBe("pickup_truck");
    expect(normalizeVehicleCategory("pickup_truck")).toBe("pickup_truck");
  });

  it("permet au client snake_case de réutiliser une ancienne pricing_version camelCase", () => {
    expect(
      resolveConfiguredVehicleCategory(["car", "cargoVan", "pickupTruck"], "cargo_van")
    ).toBe("cargoVan");
  });

  it("permet aussi une pricing_version snake_case avec un ancien client camelCase", () => {
    expect(
      resolveConfiguredVehicleCategory(["car", "cargo_van", "pickup_truck"], "pickupTruck")
    ).toBe("pickup_truck");
  });

  it("reste fail-closed lorsqu'aucune catégorie configurée ne correspond", () => {
    expect(resolveConfiguredVehicleCategory(["car", "suv"], "cube_truck")).toBeNull();
  });

  it("préserve l'éligibilité des anciens profils chauffeur camelCase", () => {
    expect(supportsVehicleCategory(["cargoVan"], "cargo_van")).toBe(true);
    expect(supportsVehicleCategory(["sedan"], "cargo_van")).toBe(false);
  });

  // Décision de Daniel, 2026-11-26.
  it("traite un VUS avec remorque comme un pick-up pour le jumelage", () => {
    expect(dispatchCategory("suvWithTrailer")).toBe("pickup_truck");
    expect(dispatchCategory("suv_with_trailer")).toBe("pickup_truck");
    expect(supportsVehicleCategory(["suv_with_trailer"], "pickup_truck")).toBe(true);
    expect(supportsVehicleCategory(["suvWithTrailer"], "pickupTruck")).toBe(true);
  });

  it("ne donne pas au VUS avec remorque les demandes réservées au fourgon ou au camion cube", () => {
    expect(supportsVehicleCategory(["suv_with_trailer"], "cargo_van")).toBe(false);
    expect(supportsVehicleCategory(["suv_with_trailer"], "cube_truck")).toBe(false);
  });

  it("laisse le VUS seul limité aux demandes ouvertes au VUS", () => {
    expect(dispatchCategory("suv")).toBe("suv");
    expect(supportsVehicleCategory(["suv"], "pickup_truck")).toBe(false);
    const sofa = {
      booking_snapshot: {
        vehicle_assessment: "driver_judgement",
        eligible_categories: ["pickup_truck", "cargo_van", "cube_truck"],
      },
    };
    expect(driverServesMissionCategory(["suv"], sofa)).toBe(false);
    expect(driverServesMissionCategory(["suv_with_trailer"], sofa)).toBe(true);
  });

  it("garde le VUS avec remorque sur une demande ouverte seulement au pick-up et au camion cube", () => {
    const materials = {
      booking_snapshot: {
        vehicle_assessment: "driver_judgement",
        eligible_categories: ["pickup_truck", "cube_truck"],
      },
    };
    expect(driverServesMissionCategory(["suv_with_trailer"], materials)).toBe(true);
  });
});
