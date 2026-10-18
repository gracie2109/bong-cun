import { describe, expect, it } from "vitest";
import { createRateLimiter, rateLimitBucket } from "../../server/utils/rateLimit";

describe("createRateLimiter", () => {
  it("allows up to the limit per window, then asks to retry", () => {
    let now = 0;
    const hit = createRateLimiter({ limit: 2, windowMs: 10_000 }, () => now);
    expect(hit("ip").allowed).toBe(true);
    expect(hit("ip").allowed).toBe(true);
    const third = hit("ip");
    expect(third.allowed).toBe(false);
    expect(third.retryAfterSec).toBe(10);
    expect(hit("other").allowed).toBe(true);
    now = 10_000;
    expect(hit("ip").allowed).toBe(true);
  });
});

describe("rateLimitBucket", () => {
  it("limits GHN quotes harder than lookups and leaves pages alone", () => {
    expect(rateLimitBucket("/api/ghn/shipping-fee")).toBe("quote");
    expect(rateLimitBucket("/api/ghn/provinces")).toBe("lookup");
    expect(rateLimitBucket("/products")).toBeNull();
  });
});
