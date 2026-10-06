# Supabase setup

The backend is a single Supabase project: Postgres (with Row Level Security),
Auth, Storage and one Edge Function. Everything is in `supabase/`.

## 1. Create the project and apply the schema

1. Create a Supabase project.
2. Apply `supabase/migrations/*` in filename order (SQL editor, `supabase db push`,
   or the Supabase MCP `apply_migration`).
3. Run `supabase/seed.sql` for reference data (roles, permissions, weight classes)
   and two sample pets/services.
4. Deploy the Edge Function `supabase/functions/admin-create-user` (keep
   **Verify JWT** on). It creates accounts on behalf of an admin; it needs the
   service role key, which Supabase injects, so it never reaches the browser.

## 2. Auth settings

Server-side auth settings live in **`supabase/config.toml`** (OTP length and
expiry, redirect URLs, the access-token hook, and the two email templates in
`supabase/templates/`). `supabase start` reads it for local development. For the
hosted project, push it with `supabase config push`, or set the same values by
hand:

| Where (dashboard) | Setting |
|---|---|
| Authentication > Hooks | Enable **Custom Access Token**, function `public.custom_access_token_hook`. Without it the JWT has no `user_role` claim and nobody is an admin. |
| Authentication > Emails > Templates | **Confirm signup** = `supabase/templates/confirm-signup.html`, **Reset Password** = `supabase/templates/recovery.html`. Both carry `{{ .Token }}` (a code), never `{{ .ConfirmationURL }}`: the app asks the user to type the code, so no link is ever sent. |
| Authentication > Emails > SMTP Settings | Configure your own SMTP. The built-in sender only mails project members and is heavily rate-limited. |
| Authentication > Providers > Email | Keep **Confirm email** on. |
| Authentication > URL Configuration | Site URL and `http://localhost:3004/**` (needed for Google login). |
| Authentication > Providers | (Optional) Google: needs a Google Cloud OAuth client. Enable *manual linking* to use "link account" on the profile page. |

Client-side code entry (accepted length, resend cooldown) is in `src/config/auth.ts`.

## 3. Environment

Copy `.env.example` to `.env` and set `VITE_SUPABASE_URL` and
`VITE_SUPABASE_PUBLISHABLE_KEY`. Never use the service_role key in `.env`.

## 4. Test accounts (dev / local / test only)

`npm run seed:test-accounts` creates one pre-confirmed account per role
(`superadmin@`, `admin@`, `cashier@`, `customer@` + `TEST_ACCOUNT_EMAIL_DOMAIN`), so
you can sign in without the email flow. It uses the Admin API with the
service-role key, so it runs from your machine, never from the browser. Set these
in `.env` (placeholders are in `.env.example`; none are `VITE_` variables):

`SUPABASE_SERVICE_ROLE_KEY`, `TEST_ACCOUNT_PASSWORD`, `TEST_ACCOUNT_EMAIL_DOMAIN`,
and `ALLOW_TEST_ACCOUNTS=true` (an explicit opt-in; the script also refuses under
`NODE_ENV=production`). It is idempotent: re-running resets the password.
Do not create these accounts in production.

## 5. First real admin

Sign up in the app, then promote the account (SQL editor):

```sql
update public.users set role = 'superAdmin' where email = 'you@example.com';
```

Sign out and back in: the role is read from the JWT, so it only changes when a
new access token is issued.

## Roles

| Role | Can do |
|---|---|
| customer | Read the catalog, make bookings, see their own bookings/orders. |
| admin | Everything above plus manage the catalog, customers, bookings and orders. |
| superAdmin | Everything an admin can, plus roles/permissions and assigning roles. |
| cashier | Currently same as customer (no admin-area access); extend the RLS policies to change that. |

## Where things live

- `src/repositories/` — pure data access (takes a Supabase client). Reusable in Nuxt.
- `src/queries/` — TanStack Query hooks over the repositories.
- `src/config/env.ts` — the only file that reads `import.meta.env`.
- `src/config/auth.ts` — client-side OTP constants. Server-side auth config: `supabase/config.toml`.
- `src/lib/access.ts` — route access rules (UX only; RLS is the real enforcement).
- `src/types/database.types.ts` — generated; regenerate after schema changes.
