import { describe, expect, it } from "vitest";
import { MAX_DELIVERY_G } from "@bongcun/core/shop";
import {
  canDeliver,
  clampQuote,
  isFreeShip,
  MAX_QUOTE_FEE,
  orderWeightG,
  PACKAGING_G,
  resolveShippingFee,
  shouldWarnFeeChange,
} from "@bongcun/core/shop";
import { serviceTypeForWeight } from "../../server/utils/ghnQuote";

describe("shipping limits", () => {
  it("shares one delivery weight limit between checkout and the GHN route", () => {
    expect(serviceTypeForWeight(MAX_DELIVERY_G)).not.toBeNull();
    expect(serviceTypeForWeight(MAX_DELIVERY_G + 1)).toBeNull();
    expect(canDeliver(MAX_DELIVERY_G)).toBe(true);
    expect(canDeliver(MAX_DELIVERY_G + 1)).toBe(false);
  });

  it("adds packaging to the goods weight", () => {
    expect(orderWeightG(1000)).toBe(1000 + PACKAGING_G);
  });

  it("clamps quotes into 0..MAX_QUOTE_FEE", () => {
    expect(clampQuote(-5)).toBe(0);
    expect(clampQuote(MAX_QUOTE_FEE + 1)).toBe(MAX_QUOTE_FEE);
    expect(clampQuote(1234.6)).toBe(1235);
  });
});

describe("resolveShippingFee", () => {
  const base = { subtotal: 100_000, freeShipFrom: 300_000, flatFee: 30_000, ghnFee: null };

  it("is free from the threshold", () => {
    expect(resolveShippingFee({ ...base, subtotal: 300_000, ghnFee: 25_000 })).toEqual({ fee: 0, source: "free" });
    expect(isFreeShip(300_000, null)).toBe(false);
    expect(isFreeShip(300_000, 0)).toBe(false);
  });

  it("uses the GHN quote, then the flat fee", () => {
    expect(resolveShippingFee({ ...base, ghnFee: 25_000 })).toEqual({ fee: 25_000, source: "ghn" });
    expect(resolveShippingFee(base)).toEqual({ fee: 30_000, source: "flat" });
  });

  it("warns only when the confirmed fee is clearly above the quote", () => {
    expect(shouldWarnFeeChange(20_000, 30_000)).toBe(false);
    expect(shouldWarnFeeChange(20_000, 30_001)).toBe(true);
  });
});
