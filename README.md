# bongCunManager

Pet-service management app: a public site (server-rendered) and an admin area
(client-rendered), built with Nuxt 4, Pinia, TanStack Query and Supabase.

## Setup

```sh
npm install
cp .env.example .env   # then fill it in, see docs/supabase-setup.md
```

## Scripts

```sh
npm run dev          # dev server on http://localhost:3004
npm run build        # production build (.output/)
npm run preview      # serve the production build
npm run type-check   # nuxt typecheck (vue-tsc)
```

## Layout

- `src/pages/` routes. Each page is a thin wrapper that sets `definePageMeta`
  (route name, layout, `titleKey`, access rules) and renders a view from `src/views/`.
- `src/middleware/auth.global.ts` route access (UX only, RLS enforces).
- `routeRules` in `nuxt.config.ts` choose SSR or SPA per route (`/admin/**`,
  auth and cart pages are SPA).
- `server/api/ghn/` proxies GHN shipping so its credentials stay on the server.
