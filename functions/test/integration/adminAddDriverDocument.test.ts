// -----------------------------------------------------------------------------
// Un agent ajoute un document reçu par courriel ; permis recto/verso ;
// plus de pièce d'identité (Daniel, 2026-11-12).
// -----------------------------------------------------------------------------
import { adminAddDriverDocument } from "../../src/functions/adminAddDriverDocument";
import { approveDriver } from "../../src/functions/approveDriver";
import { validateDriverDocument } from "../../src/functions/validateDriverDocument";
import { admin, db } from "../../src/lib/admin";

const call = (data: unknown, uid = "add_agent", roles = ["analyst"]) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const DRIVER = "add_driver_001";
const saved = new Map<string, { bytes: Buffer; options: any }>();
let bucket: jest.SpyInstance;

beforeEach(async () => {
  saved.clear();
  bucket = jest.spyOn(admin.storage(), "bucket").mockReturnValue({
    file: (name: string) => ({
      save: async (bytes: Buffer, options: any) => {
        saved.set(name, { bytes, options });
      },
    }),
  } as any);
  await db.doc(`driver_profiles/${DRIVER}`).set({ uid: DRIVER, status: "pending_review", documents_all_valid: false });
});

afterEach(async () => {
  bucket.mockRestore();
  const docs = await db.collection("driver_documents").where("driver_id", "==", DRIVER).get();
  await Promise.all(docs.docs.map((d) => d.ref.delete()));
  await db.doc(`driver_profiles/${DRIVER}`).delete();
});

const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]).toString("base64");

async function add(slot: string, mimeType = "image/png") {
  return adminAddDriverDocument.run(call({ driverId: DRIVER, slot, mimeType, fileName: `${slot}.png`, dataBase64: png }));
}

it("an agent adds a document received by email: stored, uploaded, marked staff, audited", async () => {
  const result = await add("drivers_licence_back");
  expect(result.storagePath).toMatch(new RegExp(`^driver_documents/${DRIVER}/drivers_licence_back_\\d+\\.png$`));
  expect(saved.get(result.storagePath)?.options.contentType).toBe("image/png");
  expect(saved.get(result.storagePath)?.bytes.length).toBe(7);

  const doc = (await db.doc(`driver_documents/${result.documentId}`).get()).data()!;
  expect(doc).toMatchObject({
    driver_id: DRIVER,
    type: "drivers_licence",
    status: "uploaded",
    storage_bucket_path: result.storagePath,
    source: "staff",
    added_by_user_id: "add_agent",
    file_name: "drivers_licence_back.png",
  });
  const audit = await db.collection("audit_logs").where("target_id", "==", result.documentId).get();
  expect(audit.docs[0].data()).toMatchObject({ action: "driver_document_added_by_staff" });
});

it("refuses: driver role, unknown place, identity, bad format, too heavy, unknown driver", async () => {
  await expect(adminAddDriverDocument.run(call({ driverId: DRIVER, slot: "insurance", mimeType: "image/png", dataBase64: png }, DRIVER, ["driver"])))
    .rejects.toMatchObject({ code: "permission-denied" });
  await expect(add("identity")).rejects.toMatchObject({ code: "invalid-argument" });
  await expect(add("insurance", "text/html")).rejects.toMatchObject({ code: "invalid-argument" });
  const heavy = Buffer.alloc(8 * 1024 * 1024 + 1).toString("base64");
  await expect(adminAddDriverDocument.run(call({ driverId: DRIVER, slot: "insurance", mimeType: "application/pdf", dataBase64: heavy })))
    .rejects.toMatchObject({ code: "invalid-argument" });
  await expect(adminAddDriverDocument.run(call({ driverId: "nobody", slot: "insurance", mimeType: "image/png", dataBase64: png })))
    .rejects.toMatchObject({ code: "not-found" });
  expect(saved.size).toBe(0);
});

it("approval needs licence front AND back, no identity document", async () => {
  const ids: Record<string, string> = {};
  for (const slot of ["drivers_licence_front", "vehicle_registration", "insurance"]) {
    ids[slot] = (await add(slot)).documentId;
    await validateDriverDocument.run(call({ documentId: ids[slot], newStatus: "approved" }));
  }
  expect((await db.doc(`driver_profiles/${DRIVER}`).get()).data()?.documents_all_valid).toBe(false);
  await expect(approveDriver.run(call({ driverId: DRIVER })))
    .rejects.toThrow(/drivers_licence_back/);

  ids.back = (await add("drivers_licence_back")).documentId;
  await validateDriverDocument.run(call({ documentId: ids.back, newStatus: "approved" }));
  expect((await db.doc(`driver_profiles/${DRIVER}`).get()).data()?.documents_all_valid).toBe(true);
  await approveDriver.run(call({ driverId: DRIVER }));
  expect((await db.doc(`driver_profiles/${DRIVER}`).get()).data()).toMatchObject({ status: "approved" });
});
