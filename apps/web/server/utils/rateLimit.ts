// Fixed-window rate limiter kept in memory. On Vercel each warm function instance has its own
// window, so this slows down scrapers and accidental loops; it is not a hard global quota.

export type RateLimitRule = { limit: number; windowMs: number };
export type RateLimitResult = { allowed: boolean; remaining: number; retryAfterSec: number };

type Window = { count: number; resetAt: number };

const MAX_KEYS = 5000;

export const createRateLimiter = (rule: RateLimitRule, now: () => number = Date.now) => {
  const windows = new Map<string, Window>();

  const prune = (at: number) => {
    for (const [key, w] of windows) if (w.resetAt <= at) windows.delete(key);
  };

  return (key: string): RateLimitResult => {
    const at = now();
    let w = windows.get(key);
    if (!w || w.resetAt <= at) {
      if (windows.size >= MAX_KEYS) prune(at);
      w = { count: 0, resetAt: at + rule.windowMs };
      windows.set(key, w);
    }
    w.count += 1;
    const allowed = w.count <= rule.limit;
    return {
      allowed,
      remaining: Math.max(rule.limit - w.count, 0),
      retryAfterSec: allowed ? 0 : Math.ceil((w.resetAt - at) / 1000),
    };
  };
};

/** Which bucket a path falls in, or null when it is not limited. */
export const rateLimitBucket = (path: string): "quote" | "lookup" | null => {
  if (!path.startsWith("/api/")) return null;
  // Price quotes call GHN on every request: the tighter bucket.
  if (path.startsWith("/api/ghn/shipping-fee") || path.startsWith("/api/ghn/leadtime")) return "quote";
  return "lookup";
};

export const RATE_LIMIT_RULES: Record<"quote" | "lookup", RateLimitRule> = {
  quote: { limit: 30, windowMs: 60_000 },
  lookup: { limit: 120, windowMs: 60_000 },
};
