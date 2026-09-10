import {
  normalizeVehicleCategory,
  resolveConfiguredVehicleCategory,
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
});
