import { describe, expect, it } from "vitest";
import { businessDate, isExpired } from "@bongcun/supabase/inventory";

describe("isExpired", () => {
  it("has no expiry when the lot has no date", () => {
    expect(isExpired(null)).toBe(false);
  });

  it("is expired only before today in the shop's time zone", () => {
    const today = businessDate();
    expect(isExpired(today)).toBe(false);
    expect(isExpired("2000-01-01")).toBe(true);
    expect(isExpired("2999-12-31")).toBe(false);
  });
});
