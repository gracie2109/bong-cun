# Mock second branch

For trying the multi-branch dashboard ("all branches" scope, branch picker) before a real second branch exists.

| File | What it does |
| --- | --- |
| `mock-branch-seed.sql` | Creates the branch `MOCK` with sales, online orders (delivered, on the way, returned, cancelled, waiting), stock in every state, overdue vaccines and two boarding stays, plus four `[MOCK]` customers. |
| `mock-branch-cleanup.sql` | Deletes exactly that and nothing else. |

| `mock-shift-seed.sql` | Shift registration: branch `MOCKCA` with 3 shift templates, registration open, ten staff with Vietnamese names (`mock-ca-N@mock.invalid`, nobody can sign in as them), availability, 71 shifts over last and this week, and 40 requests for the next two weeks (32 pending, some on blocked days, plus approved, rejected, cancelled). Publishing is on: last and this week published, next week a draft, one person declared "no shifts", two sample notifications for the first user. |
| `mock-shift-october.sql` | Run after `mock-shift-seed.sql`: fills October 2026 for MOCKCA with shifts, check-ins (on time, late, early out, overtime, forgotten check-out, absent), three approved leaves and an unscheduled day, so the timesheet has a full month. |
| `mock-shift-cleanup.sql` | Deletes exactly that and nothing else. |

Neither is a migration, so nothing runs them automatically. Run one with `psql "$DATABASE_URL" -f supabase/mock/<file>.sql`
or paste it into the Supabase SQL editor. Both are a single transaction, so a failure writes or deletes nothing.

What keeps the real data safe:

- Every row hangs off the branch with code `MOCK`, or is a customer/pet named `[MOCK] ...` (phones `0990000001`-`0990000009`).
- Nothing is created in the shared catalogue (products, services, kennel types, vaccine types are reused, never added).
- The public shop sends orders to `shop_settings.online_branch_id`, so customers never reach the MOCK branch.
- Checked against a copy built from every migration: after seed then cleanup, every public table has exactly the same content as before.

Admins see the MOCK branch in the branch picker; other staff only if they are given a role there.
