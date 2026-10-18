import { describe, expect, it } from "vitest";
import {
  canonicalUrl,
  hostMatches,
  isAllowedHost,
  parseHostList,
  redirectTarget,
} from "@/features/shared/security/helpers/hostAllowlist";
import { DEFAULT_ALLOWED_HOSTS } from "../../config/site";

describe("host allowlist", () => {
  const hosts = parseHostList(DEFAULT_ALLOWED_HOSTS);

  it("accepts production, previews and local dev", () => {
    for (const host of ["bong-cun.vercel.app", "bong-cun-git-main-team.vercel.app", "localhost", "127.0.0.1"]) {
      expect(isAllowedHost(host, hosts)).toBe(true);
    }
  });
  it("rejects other domains", () => {
    for (const host of ["bongcun-shop.com", "bong-cun.vercel.app.evil.com", "evil.vercel.app", "x.bong-cun.vercel.app"]) {
      expect(isAllowedHost(host, hosts)).toBe(false);
    }
  });
  it("keeps the wildcard inside one label", () => {
    expect(hostMatches("a.b.vercel.app", "*.vercel.app")).toBe(false);
    expect(hostMatches("ab.vercel.app", "*.vercel.app")).toBe(true);
    expect(hostMatches("BONG-CUN.vercel.app", "bong-cun.vercel.app")).toBe(true);
  });
  it("parses a comma list", () => {
    expect(parseHostList(" a.com, ,B.com ")).toEqual(["a.com", "b.com"]);
  });
});

describe("redirectTarget / canonicalUrl", () => {
  it("keeps path, query and hash on the real site", () => {
    expect(redirectTarget("https://bong-cun.vercel.app/", { pathname: "/products/1", search: "?a=1", hash: "#x" })).toBe(
      "https://bong-cun.vercel.app/products/1?a=1#x"
    );
  });
  it("drops query, hash and trailing slashes", () => {
    expect(canonicalUrl("https://bong-cun.vercel.app", "/products/?page=2")).toBe("https://bong-cun.vercel.app/products");
    expect(canonicalUrl("https://bong-cun.vercel.app/", "/")).toBe("https://bong-cun.vercel.app/");
  });
});
