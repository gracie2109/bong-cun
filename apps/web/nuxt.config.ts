// https://nuxt.com/docs/api/configuration/nuxt-config

// Messages are split by area (src/i18n/locales/<locale>/<area>.json) and merged per locale.
const i18nFiles = (locale: string) =>
  ["common", "shop", "services", "admin"].map((area) => `${locale}/${area}.json`);

import { mobileNuxtConfig, resolveAppTarget } from "./config/mobileTarget";

const appTarget = resolveAppTarget(process.env.NUXT_PUBLIC_APP_TARGET);

const baseConfig = defineNuxtConfig({
  compatibilityDate: "2026-10-01",
  srcDir: "src/",

  // Workspace packages ship TypeScript source.
  build: { transpile: ["@bongcun/core", "@bongcun/supabase"] },
  nitro: { externals: { inline: ["@bongcun/core"] } },

  modules: ["@pinia/nuxt", "@nuxtjs/supabase", "@nuxtjs/i18n", "@vueuse/nuxt"],

  // Components keep their explicit imports (shadcn-vue ui/* barrels would
  // collide if auto-registered).
  components: { dirs: [] },

  css: [
    "~/assets/index.css",
    "~/assets/shop.css",
  ],

  postcss: {
    plugins: { tailwindcss: {}, autoprefixer: {} },
  },

  app: {
    head: {
      bodyAttrs: { class: "dark:text-#e9e9e9 auto-bg" },
      meta: [
        {
          name: "viewport",
          content:
            "width=device-width, initial-scale=1, maximum-scale=1, shrink-to-fit=no, viewport-fit=cover",
        },
      ],
      link: [
        { rel: "icon", href: "/favicon.ico" },
        {
          rel: "stylesheet",
          href: "https://fonts.googleapis.com/css2?family=Quicksand:wght@300..700&display=swap",
        },
        {
          rel: "stylesheet",
          href: "https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap",
        },
      ],
    },
  },

  // Loader shown while ssr:false routes boot (was the #app placeholder in index.html).
  spaLoadingTemplate: true,

  // Hybrid rendering: public pages are server-rendered, signed-in areas are SPA.
  routeRules: {
    "/admin/**": { ssr: false },
    "/cart": { ssr: false },
    "/checkout": { ssr: false },
    "/orders/**": { ssr: false },
    "/profile": { ssr: false },
    "/login": { ssr: false },
    "/register": { ssr: false },
    "/forgot-password": { ssr: false },
  },

  runtimeConfig: {
    // apiBase is empty on the website (same-origin /api); the mobile build points it at the deployed server.
    public: { appTarget, apiBase: "" },
    // Server-only (NUXT_GHN_*). Never move these to `public`.
    ghn: {
      token: "",
      shopId: "",
      lightGoodsServiceId: "",
      heavyGoodsServiceId: "",
    },
  },

  supabase: {
    // Access control is done by our own middleware (src/middleware/auth.global.ts).
    redirect: false,
    types: "~~/../../packages/supabase/src/db/database.types.ts",
  },

  i18n: {
    restructureDir: "src/i18n",
    langDir: "locales",
    vueI18n: "i18n.config.ts",
    strategy: "no_prefix",
    defaultLocale: "vi",
    locales: [
      { code: "vi", language: "vi-VN", files: i18nFiles("vi") },
      { code: "en", language: "en-US", files: i18nFiles("en") },
    ],
    detectBrowserLanguage: {
      useCookie: true,
      cookieKey: "user-locale",
      fallbackLocale: "vi",
    },
  },

  typescript: {
    // Same strictness as the previous @vue/tsconfig setup.
    tsConfig: { compilerOptions: { noUncheckedIndexedAccess: false } },
  },

  devServer: { port: 3004 },

  vite: {
    optimizeDeps: { exclude: ["vue-zoomable"] },
  },
});

// The mobile build (NUXT_PUBLIC_APP_TARGET=mobile) is the same app minus admin, rendered client-side only.
const mobile = mobileNuxtConfig();

export default appTarget === "mobile"
  ? defineNuxtConfig({
      ...baseConfig,
      ...mobile,
      supabase: { ...baseConfig.supabase, ...mobile.supabase },
      runtimeConfig: {
        ...baseConfig.runtimeConfig,
        public: { ...baseConfig.runtimeConfig?.public, ...mobile.runtimeConfig.public },
      },
    })
  : baseConfig;
