import { assertProofUrlForMission } from "../../src/lib/proofUrl";

describe("SEC-04 — preuves photo : URL Cloud Storage du dossier de la mission", () => {
  const id = "mission_42";
  it("accepte les URL Cloud Storage de la mission (brute ou encodée)", () => {
    expect(assertProofUrlForMission(`https://storage.googleapis.com/movik-prod/delivery_proofs/${id}/p.jpg`, id, "f"))
      .toContain("delivery_proofs/mission_42/p.jpg");
    expect(assertProofUrlForMission(
      `https://firebasestorage.googleapis.com/v0/b/movik-prod.appspot.com/o/delivery_proofs%2F${id}%2Fp.jpg?alt=media&token=abc`, id, "f"
    )).toContain("delivery_proofs%2Fmission_42%2Fp.jpg");
  });
  it("refuse un lien externe, http, une autre mission, un autre dossier", () => {
    expect(() => assertProofUrlForMission("https://evil.example/photo.jpg", id, "f")).toThrow("stockage Movi-K");
    expect(() => assertProofUrlForMission(`http://storage.googleapis.com/b/delivery_proofs/${id}/p.jpg`, id, "f")).toThrow("HTTPS");
    expect(() => assertProofUrlForMission("https://storage.googleapis.com/b/delivery_proofs/other/p.jpg", id, "f")).toThrow("cette livraison");
    expect(() => assertProofUrlForMission(`https://storage.googleapis.com/b/profile_photos/${id}/p.jpg`, id, "f")).toThrow("cette livraison");
    expect(() => assertProofUrlForMission("", id, "f")).toThrow("requis");
    expect(() => assertProofUrlForMission("not a url", id, "f")).toThrow("URL valide");
  });
  it("les hôtes de test ne sont acceptés que via PROOF_URL_TEST_HOSTS", () => {
    const saved = process.env.PROOF_URL_TEST_HOSTS;
    process.env.PROOF_URL_TEST_HOSTS = "";
    expect(() => assertProofUrlForMission("https://storage.example.test/delivery_proofs/p.jpg", id, "f")).toThrow("stockage Movi-K");
    process.env.PROOF_URL_TEST_HOSTS = "storage.example.test";
    expect(assertProofUrlForMission("https://storage.example.test/delivery_proofs/p.jpg", id, "f")).toContain("storage.example.test");
    process.env.PROOF_URL_TEST_HOSTS = saved;
  });
});
