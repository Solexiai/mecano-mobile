// Client, chauffeur ou personnel : un compte est une seule chose (Daniel, 2026-11-17).
import { refuseDriverAsCustomer, userKind } from "../../src/lib/userKind";

describe("userKind", () => {
  it("classe : personnel > chauffeur > client", () => {
    expect(userKind(["customer"])).toBe("customer");
    expect(userKind(["customer", "driver"])).toBe("driver");
    expect(userKind(["driver"])).toBe("driver");
    expect(userKind(["customer", "driver", "super_admin"])).toBe("staff");
    expect(userKind(["analyst"])).toBe("staff");
    expect(userKind(undefined)).toBe("none");
  });

  it("un chauffeur ne réserve pas ; le personnel et les clients, oui", () => {
    expect(() => refuseDriverAsCustomer(["customer", "driver"])).toThrow(/compte chauffeur/);
    expect(() => refuseDriverAsCustomer(["customer"])).not.toThrow();
    expect(() => refuseDriverAsCustomer(["customer", "driver", "admin"])).not.toThrow();
    expect(() => refuseDriverAsCustomer(undefined)).not.toThrow();
  });
});
