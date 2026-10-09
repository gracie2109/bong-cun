---
name: personal-supabase-standards
description: Personal Supabase standards. Use ONLY when the project actually uses Supabase (supabase-js, @supabase/ssr, supabase/ directory, migrations, RLS, Supabase Auth/Storage). Covers OTP email auth, test accounts, migrations, RLS, service-role key handling and data-access layering.
---

# Personal Supabase Standards

Apply only if the project really uses Supabase. Project rules override this file, except the security rules.
Complements (does not replace) the official `supabase:supabase` skill — load that too for API details.

## Auth

- For email verification flows (signup confirmation, password reset, email verification, similar), prefer OTP / verification code over clickable email links whenever the flow supports it.
- Manage auth configuration in one central place: OTP expiry, redirect URLs, email templates, timeouts. Don't scatter these literals through components.
- Magic links are acceptable only when OTP isn't feasible for the flow; say why.

## Test account

- Every project has a dedicated test account for development/testing.
- It must not depend on the email-confirmation flow (create it pre-confirmed, e.g. Admin API `email_confirm: true`).
- Create/manage it via a seed or setup script or the Admin API, run in local/dev/test environments only.
- Credentials come from environment variables (documented in `.env.example` with placeholders). Never hardcode them in source.
- The script that uses the service-role key runs server-side/locally, never in the browser bundle.

## Database & migrations

- Schema is managed only through Supabase migrations (`supabase/migrations`).
- No manual production schema changes without a matching migration committed to the repo.
- Prefer local testing (`supabase start`) before applying remotely.
- Inspect existing tables/policies before changing the schema.

## RLS & security

- Every table holding application data: review and configure RLS (enable it, add explicit policies per operation).
- Never rely on client-side checks to protect data.
- After schema changes, run the Supabase security/performance advisors and fix findings.
- `SUPABASE_SERVICE_ROLE_KEY`: server or secure environment only. Never in browser code, never in a public-prefixed env var (`VITE_`, `NEXT_PUBLIC_`, `EXPO_PUBLIC_`…), never committed.
- Client uses only the URL + anon/publishable key.

## Data access

- Don't scatter `supabase.from(...)` calls across UI components when the project can have a feature/data-access boundary; follow the project's existing layering if it has one.
- Reuse the existing Supabase client instance and data-access helpers.
- Keep UI logic, business logic, data access, and validation/transformation separate where it reduces coupling — not as ceremony.
- Don't duplicate the same query or row-to-model transformation in several places.
- Use generated types (`supabase gen types`) if the project already does.
