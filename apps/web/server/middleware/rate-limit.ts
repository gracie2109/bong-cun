import { RATE_LIMIT_RULES, createRateLimiter, rateLimitBucket } from "../utils/rateLimit";

// Per-IP limits for the public /api routes (the GHN proxy and the catalog reads). Runs after ghn-cors, so a 429
// still carries the app's CORS headers; preflights are not counted.
const limiters = {
  quote: createRateLimiter(RATE_LIMIT_RULES.quote),
  lookup: createRateLimiter(RATE_LIMIT_RULES.lookup),
  catalog: createRateLimiter(RATE_LIMIT_RULES.catalog),
};

export default defineEventHandler((event) => {
  if (event.method === "OPTIONS") return;
  const bucket = rateLimitBucket(event.path);
  if (!bucket) return;

  const ip = getRequestIP(event, { xForwardedFor: true }) ?? "unknown";
  const result = limiters[bucket](ip);
  setResponseHeader(event, "X-RateLimit-Remaining", result.remaining);
  if (result.allowed) return;

  setResponseHeader(event, "Retry-After", result.retryAfterSec);
  throw createError({ statusCode: 429, statusMessage: "Too many requests" });
});
