import { describe, expect, it } from "vitest";
import { apiUrl } from "@/utils/apiUrl";
import { appCorsHeaders } from "../../server/utils/appCors";

describe("apiUrl", () => {
  it("stays relative when there is no base (website)", () => {
    expect(apiUrl("", "/api/ghn/provinces")).toBe("/api/ghn/provinces");
    expect(apiUrl(undefined, "/api/ghn/provinces")).toBe("/api/ghn/provinces");
  });

  it("prefixes the base without doubling slashes (app)", () => {
    expect(apiUrl("https://bong-cun.vercel.app", "/api/ghn/wards")).toBe("https://bong-cun.vercel.app/api/ghn/wards");
    expect(apiUrl("https://bong-cun.vercel.app/", "api/ghn/wards")).toBe("https://bong-cun.vercel.app/api/ghn/wards");
  });
});

describe("appCorsHeaders", () => {
  it("allows only the app origins and echoes the origin back", () => {
    expect(appCorsHeaders("https://localhost")?.["Access-Control-Allow-Origin"]).toBe("https://localhost");
    expect(appCorsHeaders("capacitor://localhost")?.["Access-Control-Allow-Origin"]).toBe("capacitor://localhost");
  });

  it("gives nothing to other origins", () => {
    expect(appCorsHeaders("https://evil.example")).toBeNull();
    expect(appCorsHeaders("http://localhost")).toBeNull();
    expect(appCorsHeaders(undefined)).toBeNull();
  });
});
