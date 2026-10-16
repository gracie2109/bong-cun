# bongCunManager

Pet-service management app: a public site (server-rendered) and an admin area
(client-rendered), built with Nuxt 4, Pinia, TanStack Query and Supabase.

## Setup

```sh
npm install
cp apps/web/.env.example apps/web/.env   # then fill it in, see docs/supabase-setup.md
```

## Scripts

```sh
npm run dev          # dev server on http://localhost:3004
npm run build        # production build (.output/)
npm run preview      # serve the production build
npm run type-check   # nuxt typecheck (vue-tsc)
npm test             # Vitest unit tests (apps/web/tests/unit)
npm run deps:check   # dependency-cruiser layer rules
npm run db:start     # local database with every migration applied (needs Docker)
npm run db:test      # SQL tests in supabase/tests
npm run db:schema    # regenerate supabase/schema.sql after adding a migration
```

## Layout

npm workspaces: the Nuxt app is `apps/web/` (all paths below are relative to it),
`packages/core` is framework-free TypeScript (errors, page types, access rules),
`packages/supabase` is the only place that imports supabase-js (generated DB types, RPC helpers),
and `supabase/` stays at the repo root.
See docs/ke-hoach-monorepo.md.

- `src/pages/` routes. Each page is a thin wrapper that sets `definePageMeta`
  (route name, layout, `titleKey`, access rules) and renders a view from `src/views/`.
- `src/middleware/auth.global.ts` route access (UX only, RLS enforces).
- `routeRules` in `nuxt.config.ts` choose SSR or SPA per route (`/admin/**`,
  auth and cart pages are SPA).
- `server/api/ghn/` proxies GHN shipping so its credentials stay on the server.
