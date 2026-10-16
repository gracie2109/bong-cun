/**
 * Layer rules for src/. Run with `npm run deps:check`.
 * Screens use @bongcun/supabase for data; only that package imports supabase-js.
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: "supabase-js-only-in-package",
      comment: "Data access lives in @bongcun/supabase. The auth store is the one leftover (session handling moves to core/auth later).",
      severity: "error",
      from: { path: "^src", pathNot: "^src/stores/modules/auth(-parts/|\\.ts$)" },
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
