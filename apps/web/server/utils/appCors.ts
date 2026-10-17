// Origins of the Capacitor app's WebView: Android serves it from https://localhost,
// iOS (later) from capacitor://localhost. The website itself is same-origin and needs no CORS.
export const APP_ORIGINS = ["https://localhost", "capacitor://localhost"] as const;

const ALLOWED_METHODS = "GET, POST, OPTIONS";
const ALLOWED_HEADERS = "Content-Type";

/** CORS headers for an allowed app origin, or null for anything else (no `*`). */
export const appCorsHeaders = (origin: string | undefined): Record<string, string> | null => {
  if (!origin || !(APP_ORIGINS as readonly string[]).includes(origin)) return null;
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": ALLOWED_METHODS,
    "Access-Control-Allow-Headers": ALLOWED_HEADERS,
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
};
