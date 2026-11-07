import {
  APP_VERSION_POLICY_DEFAULTS,
  MAX_BUILD_NUMBER,
  parseMinBuild,
  readAppVersionPolicy,
} from "../../src/lib/appVersionPolicy";

describe("2026-11-06 — version minimale de l'app Android (app_config/app_versions)", () => {
  test("parseMinBuild accepte un entier entre 0 et la borne", () => {
    expect(parseMinBuild(0)).toEqual({ ok: true, value: 0 });
    expect(parseMinBuild(10)).toEqual({ ok: true, value: 10 });
    expect(parseMinBuild(MAX_BUILD_NUMBER)).toEqual({ ok: true, value: MAX_BUILD_NUMBER });
  });

  test("parseMinBuild refuse ce qui bloquerait tout le monde ou n'est pas un build", () => {
    expect(parseMinBuild(-1).ok).toBe(false);
    expect(parseMinBuild(MAX_BUILD_NUMBER + 1).ok).toBe(false);
    expect(parseMinBuild(10.5).ok).toBe(false);
    expect(parseMinBuild("10").ok).toBe(false);
    expect(parseMinBuild(undefined).ok).toBe(false);
  });

  test("readAppVersionPolicy : document absent ou corrompu => aucun minimum (jamais de blocage par accident)", () => {
    expect(readAppVersionPolicy(undefined)).toEqual({ ...APP_VERSION_POLICY_DEFAULTS });
    expect(readAppVersionPolicy({ android_min_build: "12", note: 3 })).toEqual({ ...APP_VERSION_POLICY_DEFAULTS });
    expect(readAppVersionPolicy({ android_min_build: -4 })).toEqual({ ...APP_VERSION_POLICY_DEFAULTS });
    expect(readAppVersionPolicy({ android_min_build: 11, note: "dépôt 25 $" })).toEqual({
      android_min_build: 11,
      note: "dépôt 25 $",
    });
  });
});
