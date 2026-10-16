/**
 * Layer rules for src/. Run with `npm run deps:check`.
 * Data access (repositories) and plain TypeScript must not reach up into screens or framework code.
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: "repositories-no-upper-layers",
      comment: "Repositories are plain TypeScript that take a Supabase client; they must not import screens, queries, stores or components.",
      severity: "error",
      from: { path: "^src/repositories" },
      to: { path: "^src/(views|queries|stores|components|composables|layouts|pages)" },
    },
    {
      name: "repositories-no-framework",
      comment: "No Vue, Nuxt, Pinia or TanStack in repositories, so they can move to a framework-free package.",
      severity: "error",
      from: { path: "^src/repositories" },
      to: { path: "node_modules/(vue|nuxt|@nuxt|pinia|@pinia|@tanstack|vue-router|@vueuse)(/|$)" },
    },
    {
      name: "queries-no-views",
      comment: "Query hooks sit below screens.",
      severity: "error",
      from: { path: "^src/queries" },
      to: { path: "^src/(views|components|pages|layouts)" },
    },
    {
      name: "types-no-upper-layers",
      comment: "Types sit below screens, queries and stores. (repositories/products/types is still imported by types/catalog; it moves to the core package in phase 2.)",
      severity: "error",
      from: { path: "^src/types", pathNot: "\\.d\\.ts$" },
      to: { path: "^src/(views|queries|stores|components|composables)" },
    },
    {
      name: "admin-views-not-client-views",
      comment: "Admin and shop screens must stay separable: shared pieces live in components/common.",
      severity: "error",
      from: { path: "^src/views/admin" },
      to: { path: "^src/views/(client|home|auth)" },
    },
    {
      name: "client-views-not-admin-views",
      severity: "error",
      from: { path: "^src/views/(client|home|auth)" },
      to: { path: "^src/views/admin" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: "tsconfig.deps.json" },
    includeOnly: "^src|node_modules/(vue|nuxt|@nuxt|pinia|@pinia|@tanstack|vue-router|@vueuse)",
    enhancedResolveOptions: { extensions: [".ts", ".vue", ".js", ".json"], mainFields: ["module", "main", "types"] },

  },
};
