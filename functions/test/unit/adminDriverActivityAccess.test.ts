jest.mock("firebase-functions/v2/https", () => ({
 onCall: (handler: unknown) => handler,
 HttpsError: class extends Error { constructor(public code: string, message: string) {super(message);} },
}));
jest.mock("../../src/lib/admin", () => ({db:{collection:jest.fn()}}));
jest.mock("../../src/lib/auth", () => ({
 requireSignedIn:jest.fn(()=>({uid:"staff"})), requireAnalystOrAbove:jest.fn(),
}));
import {getAdminDriverActivity} from "../../src/functions/getAdminDriverActivity";
import {requireAnalystOrAbove,requireSignedIn} from "../../src/lib/auth";
import {db} from "../../src/lib/admin";
const invoke=(data:unknown)=>(getAdminDriverActivity as any)({data});
afterEach(()=>jest.clearAllMocks());
test("refuses unauthenticated callers before reading records",async()=>{
 (requireSignedIn as jest.Mock).mockImplementationOnce(()=>{throw Error("unauthenticated");});
 await expect(invoke({driverId:"d"})).rejects.toThrow("unauthenticated");
 expect(db.collection).not.toHaveBeenCalled();
});
test("refuses non-staff callers before reading records",async()=>{
 (requireAnalystOrAbove as jest.Mock).mockImplementationOnce(()=>{throw Error("denied");});
 await expect(invoke({driverId:"d"})).rejects.toThrow("denied");
 expect(db.collection).not.toHaveBeenCalled();
});
test.each([undefined,"","a/b","x".repeat(129),42])("rejects invalid driver id %s",async driverId=>{
 await expect(invoke({driverId})).rejects.toMatchObject({code:"invalid-argument"});
 expect(db.collection).not.toHaveBeenCalled();
});
