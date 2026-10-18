import { describe, expect, it } from "vitest";
import { parseProxyImageUrl, proxyImageType, readCapped } from "../../server/utils/imageProxy";
import { bearerToken } from "../../server/utils/staffAuth";

describe("parseProxyImageUrl", () => {
  it("accepts a plain https address on an allowed host", () => {
    const url = parseProxyImageUrl("https://fexafkqzpbzjcupvbfhe.supabase.co/storage/v1/object/public/product-images/a.jpg");
    expect(url?.hostname).toBe("fexafkqzpbzjcupvbfhe.supabase.co");
  });

  it("rejects other hosts, look-alikes, other schemes, ports and credentials", () => {
    for (const raw of [
      "https://example.com/a.jpg",
      "https://fexafkqzpbzjcupvbfhe.supabase.co.evil.example/a.jpg",
      "http://auth.paddy.vn/a.jpg",
      "https://auth.paddy.vn:8443/a.jpg",
      "https://user:pass@auth.paddy.vn/a.jpg",
      "https://169.254.169.254/latest/meta-data",
      "not a url",
    ]) {
      expect(parseProxyImageUrl(raw), raw).toBeNull();
    }
  });
});

describe("proxyImageType", () => {
  it("keeps picture types and drops parameters", () => {
    expect(proxyImageType("image/jpeg; charset=binary")).toBe("image/jpeg");
    expect(proxyImageType("IMAGE/PNG")).toBe("image/png");
  });

  it("refuses anything else", () => {
    expect(proxyImageType("text/html")).toBeNull();
    expect(proxyImageType("image/svg+xml")).toBeNull();
    expect(proxyImageType(null)).toBeNull();
  });
});

describe("readCapped", () => {
  const response = (body: Uint8Array, headers: Record<string, string> = {}) => new Response(body, { headers });

  it("returns the bytes of a body within the limit", async () => {
    const bytes = await readCapped(response(new Uint8Array([1, 2, 3])), 10);
    expect([...(bytes ?? [])]).toEqual([1, 2, 3]);
  });

  it("returns null when the body is over the limit", async () => {
    expect(await readCapped(response(new Uint8Array(11)), 10)).toBeNull();
  });

  it("returns null when the declared size is already over the limit", async () => {
    expect(await readCapped(response(new Uint8Array(1), { "content-length": "999" }), 10)).toBeNull();
  });
});

describe("bearerToken", () => {
  it("reads the token of a Bearer header", () => {
    expect(bearerToken("Bearer abc.def")).toBe("abc.def");
  });

  it("gives an empty string for anything else", () => {
    expect(bearerToken(undefined)).toBe("");
    expect(bearerToken("Basic abc")).toBe("");
  });
});
