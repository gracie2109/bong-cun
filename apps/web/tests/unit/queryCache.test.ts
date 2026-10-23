import { describe, expect, it } from "vitest";
import { shouldClearQueryCache } from "@/lib/query-cache";

describe("shouldClearQueryCache", () => {
  it("keeps the cache on the first session and on token refreshes", () => {
    expect(shouldClearQueryCache(undefined, "a")).toBe(false);
    expect(shouldClearQueryCache(undefined, null)).toBe(false);
    expect(shouldClearQueryCache("a", "a")).toBe(false);
    expect(shouldClearQueryCache(null, null)).toBe(false);
  });

  it("clears it on sign-out, sign-in and account switch", () => {
    expect(shouldClearQueryCache("a", null)).toBe(true);
    expect(shouldClearQueryCache(null, "a")).toBe(true);
    expect(shouldClearQueryCache("a", "b")).toBe(true);
  });
});
