// The only file that reads import.meta.env. When this app moves to Nuxt, only
// this file changes (to useRuntimeConfig); nothing else needs to know where
// configuration comes from. Every value here is bundled into the client, so it
// is public: never put a server-side secret in a VITE_* variable.
const required = (name: string, value: string | undefined): string => {
  if (!value) {
    throw new Error(
      `Missing environment variable ${name}. Copy .env.example to .env and fill it in.`
    );
  }
  return value;
};

export const env = {
  // Supabase: public URL + publishable key (protected by RLS, not by secrecy).
  supabaseUrl: required("VITE_SUPABASE_URL", import.meta.env.VITE_SUPABASE_URL),
  supabasePublishableKey: required(
    "VITE_SUPABASE_PUBLISHABLE_KEY",
    import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
  ),

  // Router base path. Empty when served from the domain root (vercel.json does).
  publicPath: (import.meta.env.VITE_PUBLIC_PATH as string | undefined) || "",

  // i18n
  defaultLocale: import.meta.env.VITE_DEFAULT_LOCALE as string | undefined,
  fallbackLocale: import.meta.env.VITE_FALLBACK_LOCALE as string | undefined,
  supportedLocales: required(
    "VITE_SUPPORTED_LOCALES",
    import.meta.env.VITE_SUPPORTED_LOCALES
  ).split(","),

  // GHN shipping (optional; the address dropdowns stay empty without a token).
  // NOTE: this token is bundled into the browser, so it is readable by anyone.
  // A server-side proxy is the real fix and fits naturally into the Nuxt move.
  ghnToken: import.meta.env.VITE_APP_GHN_TOKEN as string | undefined,
  ghnLightGoodsServiceId: import.meta.env.VITE_APP_GHN_SERVICE_ID_TYPE_LIGHT_GOODS as
    | string
    | undefined,
};
