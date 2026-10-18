import { describe, expect, it } from "vitest";
import type { ImportRow } from "@bongcun/core/data-io";
import { externalImageUrls, isExternalImage, swapImageUrls } from "@/features/admin/products/import/rehostPlan";

const OWN = "own.supabase.co";
const OWN_URL = "https://own.supabase.co/storage/v1/object/public/images/catalog/a.webp";
const OUTSIDE = "https://auth.paddy.vn/storage/v1/object/public/product-images/a.jpg";
const OUTSIDE_2 = "https://cdn.shopify.com/s/files/b.jpg";

const row = (images: string[]): ImportRow => ({ row: "1", group: "g", images }) as ImportRow;

describe("isExternalImage", () => {
  it("tells our own storage from other sites", () => {
    expect(isExternalImage(OWN_URL, OWN)).toBe(false);
    expect(isExternalImage(OUTSIDE, OWN)).toBe(true);
    expect(isExternalImage("not a url", OWN)).toBe(false);
  });
});

describe("externalImageUrls", () => {
  it("lists each outside address once, in order, and skips our own", () => {
    const rows = [row([OWN_URL, OUTSIDE]), row([OUTSIDE_2, OUTSIDE])];
    expect(externalImageUrls(rows, OWN)).toEqual([OUTSIDE, OUTSIDE_2]);
  });
});

describe("swapImageUrls", () => {
  it("replaces copied pictures, keeps our own and drops outside ones without a copy", () => {
    const copies = new Map([[OUTSIDE, "https://own.supabase.co/copy.webp"]]);
    const [result] = swapImageUrls([row([OUTSIDE, OWN_URL, OUTSIDE_2])], OWN, copies);
    expect(result?.images).toEqual(["https://own.supabase.co/copy.webp", OWN_URL]);
  });

  it("does not change the rows it was given", () => {
    const rows = [row([OUTSIDE])];
    swapImageUrls(rows, OWN, new Map());
    expect(rows[0]?.images).toEqual([OUTSIDE]);
  });
});
