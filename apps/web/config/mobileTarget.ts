// Build target "mobile": the customer part of the app as a static SPA for the Capacitor WebView.
// Pure helpers only, so nuxt.config.ts stays short and the rules are easy to test.

export const DEFAULT_API_BASE = "https://bong-cun.vercel.app";

export type AppTarget = "web" | "mobile";

type PageLike = { path: string; children?: PageLike[] };

export const resolveAppTarget = (value: string | undefined): AppTarget =>
  value === "mobile" ? "mobile" : "web";

/** Admin screens never ship in the app. */
export const isAdminRoute = (path: string): boolean =>
  path === "/admin" || path.startsWith("/admin/");

/** Removes admin routes in place, children included. */
export const dropAdminRoutes = (pages: PageLike[]): void => {
  for (let i = pages.length - 1; i >= 0; i--) {
    const page = pages[i]!;
    if (isAdminRoute(page.path)) pages.splice(i, 1);
    else if (page.children) dropAdminRoutes(page.children);
  }
};

/** The slice of Nuxt config the mobile build adds on top of the shared one. */
export const mobileNuxtConfig = () => ({
  ssr: false,
  // Native glue (status bar, Back button, offline banner...) exists only in the app build.
  plugins: ["~/features/native/plugins/native.client"],
  // The WebView has no server, so no cookie is ever set for the session: keep it in localStorage.
  supabase: { useSsrCookies: false },
  // The app has no server of its own, so /api/ghn goes to the deployed site (override: NUXT_PUBLIC_API_BASE).
  runtimeConfig: { public: { apiBase: DEFAULT_API_BASE } },
  hooks: {
    "pages:extend": (pages: PageLike[]) => dropAdminRoutes(pages),
  },
});
