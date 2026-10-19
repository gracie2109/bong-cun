import { describe, expect, it } from "vitest";
import { isServerRenderedPath, needsDocumentLoad } from "../../src/utils/shop/serverRendered";

describe("isServerRenderedPath", () => {
  it("covers the public shop pages and their sub-pages", () => {
    for (const path of ["/", "/products", "/products/abc", "/spa", "/boarding", "/about-us", "/contact"]) {
      expect(isServerRenderedPath(path)).toBe(true);
    }
  });

  it("leaves client-side pages alone", () => {
    for (const path of ["/cart", "/checkout", "/spa/book", "/account", "/admin/pos", "/login", "/productsx"]) {
      expect(isServerRenderedPath(path)).toBe(false);
    }
  });
});

describe("needsDocumentLoad", () => {
  it("reloads when moving to another server-rendered page", () => {
    expect(needsDocumentLoad("/", "/products")).toBe(true);
    expect(needsDocumentLoad("/products", "/products/abc")).toBe(true);
    expect(needsDocumentLoad("/cart", "/spa")).toBe(true);
  });

  it("stays in the browser for the same page or a client-side page", () => {
    expect(needsDocumentLoad("/products", "/products")).toBe(false);
    expect(needsDocumentLoad("/products", "/cart")).toBe(false);
    expect(needsDocumentLoad("/spa", "/spa/book")).toBe(false);
  });
});
