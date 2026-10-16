/**
 * Boundary rules for packages/. Run with `npm run deps:check` from the repo root.
 * @type {import('dependency-cruiser').IConfiguration}
 */
const FRAMEWORK = "^(vue|nuxt|@nuxt|@nuxtjs|pinia|@pinia|@tanstack|vue-router|@vueuse|@supabase)(/|$)";

module.exports = {
  forbidden: [
    {
      name: "core-framework-free",
      comment: "core is plain TypeScript: no Vue, Nuxt, Pinia, TanStack or supabase-js, and no other package.",
      severity: "error",
      from: { path: "^packages/core/src" },
      to: { dependencyTypesNot: ["local"], path: "^(?!packages/core)", pathNot: "node_modules/(zod|date-fns)(/|$)" },
    },
    {
      name: "core-no-supabase-package",
      severity: "error",
      from: { path: "^packages/core/src" },
      to: { path: "^packages/supabase" },
    },
    {
      name: "supabase-only-core",
      comment: "packages/supabase may use core, supabase-js and zod; never a framework or an app.",
      severity: "error",
      from: { path: "^packages/supabase/src" },
      to: { path: "^(apps/|node_modules/(vue|nuxt|@nuxt|@nuxtjs|pinia|@pinia|@tanstack|vue-router|@vueuse)(/|$))" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsPreCompilationDeps: true,
    enhancedResolveOptions: { extensions: [".ts", ".js", ".json"], mainFields: ["module", "main", "types"], exportsFields: ["exports"], conditionNames: ["import", "types", "default"] },
  },
};
