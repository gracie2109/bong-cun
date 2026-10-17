/**
 * Layer rules for src/. Run with `npm run deps:check`.
 * Screens use @bongcun/supabase for data; only that package imports supabase-js.
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: "supabase-js-only-in-package",
      comment: "Data access lives in @bongcun/supabase, which re-exports the few supabase-js types the app needs.",
      severity: "error",
      from: { path: "^src" },
      to: { path: "node_modules/@supabase/" },
    },
    {
      name: "queries-no-features",
      comment: "Query hooks sit below screens.",
      severity: "error",
      from: { path: "^src/queries" },
      to: { path: "^src/(features|components|pages|layouts)" },
    },
    {
      name: "types-no-upper-layers",
      comment: "Types sit below screens, queries and stores.",
      severity: "error",
      from: { path: "^src/types", pathNot: "\\.d\\.ts$" },
      to: { path: "^src/(features|queries|stores|components|composables)" },
    },
    {
      name: "admin-features-not-shop-features",
      comment: "Admin and shop screens must stay separable: shared pieces live in components/common.",
      severity: "error",
      from: { path: "^src/features/admin" },
      to: { path: "^src/features/(shop|home|auth)" },
    },
    {
      name: "shop-features-not-admin-features",
      severity: "error",
      from: { path: "^src/features/(shop|home|auth)" },
      to: { path: "^src/features/admin" },
    },
    {
      name: "feature-via-index",
      comment: "A feature reaches another feature only through its index.ts (or its pure format.ts); inside a feature, files import each other directly.",
      severity: "error",
      from: { path: "^src/features/([^/]+)/([^/]+)/" },
      to: {
        path: "^src/features/[^/]+/[^/]+/",
        pathNot: ["^src/features/$1/$2/", "^src/features/[^/]+/[^/]+/(index|format)\\.ts$"],
      },
    },
    {
      name: "shared-features-standalone",
      comment: "features/shared holds what admin and shop both use, so it may not import either of them.",
      severity: "error",
      from: { path: "^src/features/shared/" },
      to: { path: "^src/features/(admin|shop|auth|home)/" },
    },
    {
      name: "queries-infra-only",
      comment: "src/queries keeps only keys, invalidate and notify; query hooks live in their feature.",
      severity: "error",
      from: {},
      to: { path: "^src/queries/", pathNot: "^src/queries/(keys|invalidate|notify)\\.ts$" },
    },
    {
      name: "no-circular-features",
      comment: "Features may not import each other in a loop, also not through their index.ts.",
      severity: "error",
      from: { path: "^src/features/" },
      to: { circular: true },
    },
    {
      name: "features-no-pages",
      comment: "Pages are thin shells that render a feature view; features never import pages or layouts.",
      severity: "error",
      from: { path: "^src/features" },
      to: { path: "^src/(pages|layouts)" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: "tsconfig.deps.json" },
    includeOnly: "^src|node_modules/(vue|nuxt|@nuxt|pinia|@pinia|@tanstack|vue-router|@vueuse|@supabase)",
    enhancedResolveOptions: { extensions: [".ts", ".vue", ".js", ".json"], mainFields: ["module", "main", "types"] },

  },
};
