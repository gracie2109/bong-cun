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

  it("reloads when the product list's search, filters, sort or page change", () => {
    expect(needsDocumentLoad("/products", "/products?q=cat")).toBe(true);
    expect(needsDocumentLoad("/products?q=cat", "/products?q=cat&page=2")).toBe(true);
    expect(needsDocumentLoad("/products?page=2", "/products")).toBe(true);
  });

  it("stays in the browser for a hash change, another page's query or a client-side page", () => {
    expect(needsDocumentLoad("/products", "/products")).toBe(false);
    expect(needsDocumentLoad("/products?q=a", "/products?q=a#top")).toBe(false);
    expect(needsDocumentLoad("/spa", "/spa?x=1")).toBe(false);
    expect(needsDocumentLoad("/products", "/cart")).toBe(false);
    expect(needsDocumentLoad("/spa", "/spa/book")).toBe(false);
  });
});
