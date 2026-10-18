import { describe, expect, it } from "vitest";
import { STATIC_SECURITY_HEADERS, buildCsp, supabaseOrigins } from "../../config/securityHeaders";

describe("supabaseOrigins", () => {
  it("allows the project's https and websocket origins", () => {
    expect(supabaseOrigins("https://abc.supabase.co")).toEqual(["https://abc.supabase.co", "wss://abc.supabase.co"]);
  });
  it("falls back to any Supabase project when the URL is unknown", () => {
    expect(supabaseOrigins(undefined)).toEqual(["https://*.supabase.co", "wss://*.supabase.co"]);
    expect(supabaseOrigins("not a url")).toEqual(["https://*.supabase.co", "wss://*.supabase.co"]);
  });
});

describe("buildCsp", () => {
  const csp = buildCsp("https://abc.supabase.co");
  const directive = (name: string) => csp.split("; ").find((d) => d.startsWith(`${name} `));

  it("forbids framing by other sites", () => {
    expect(directive("frame-ancestors")).toBe("frame-ancestors 'self'");
    expect(STATIC_SECURITY_HEADERS["X-Frame-Options"]).toBe("SAMEORIGIN");
  });
  it("lets the app talk to Supabase and load Google fonts", () => {
    expect(directive("connect-src")).toBe("connect-src 'self' https://abc.supabase.co wss://abc.supabase.co");
    expect(directive("style-src")).toContain("https://fonts.googleapis.com");
    expect(directive("font-src")).toContain("https://fonts.gstatic.com");
  });
  it("keeps plugins and eval out", () => {
    expect(directive("object-src")).toBe("object-src 'none'");
    expect(csp).not.toContain("unsafe-eval");
  });
});
