// Security headers. Pure helpers: the static ones go into routeRules (so Vercel's CDN sends
// them for static files too); the CSP needs the runtime Supabase URL and is set by
// server/middleware/security-headers.ts.

/** Headers that never change between deployments. */
export const STATIC_SECURITY_HEADERS: Record<string, string> = {
  "X-Frame-Options": "SAMEORIGIN",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy":
    "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
};

/** `https://x.supabase.co` → `["https://x.supabase.co", "wss://x.supabase.co"]`; any project when unknown. */
export const supabaseOrigins = (supabaseUrl: string | undefined): string[] => {
  try {
    const { host } = new URL(supabaseUrl ?? "");
    if (host) return [`https://${host}`, `wss://${host}`];
  } catch {
    // Missing or malformed URL: fall through to the wildcard.
  }
  return ["https://*.supabase.co", "wss://*.supabase.co"];
};

/**
 * Content-Security-Policy for the website. Nuxt inlines its boot script and Tailwind/Vue
 * set inline styles, so `'unsafe-inline'` stays for scripts and styles; everything else is
 * narrowed. Images may come from any https host (Supabase Storage, catalog images pasted
 * as URLs, Google avatars).
 */
export const buildCsp = (supabaseUrl: string | undefined): string => {
  const directives: Record<string, string[]> = {
    "default-src": ["'self'"],
    "script-src": ["'self'", "'unsafe-inline'"],
    "style-src": ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
    "font-src": ["'self'", "data:", "https://fonts.gstatic.com"],
    "img-src": ["'self'", "data:", "blob:", "https:"],
    "connect-src": ["'self'", ...supabaseOrigins(supabaseUrl)],
    // Google Maps embed on the contact page.
    "frame-src": ["https://www.google.com"],
    "frame-ancestors": ["'self'"],
    "worker-src": ["'self'", "blob:"],
    "manifest-src": ["'self'"],
    "object-src": ["'none'"],
    "base-uri": ["'self'"],
    "form-action": ["'self'"],
  };
  return Object.entries(directives)
    .map(([name, values]) => `${name} ${values.join(" ")}`)
    .join("; ");
};
