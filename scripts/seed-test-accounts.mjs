#!/usr/bin/env node
/**
 * Creates (or refreshes) the dev/test accounts. DEV / LOCAL / TEST ONLY.
 *
 * The accounts are created already email-confirmed through the Admin API, so they
 * work without the email-verification flow. The script is idempotent: an existing
 * account gets its password reset and is confirmed again.
 *
 *   npm run seed:test-accounts        (= node --env-file=.env scripts/seed-test-accounts.mjs)
 *
 * Needs, from the environment (see .env.example):
 *   NUXT_PUBLIC_SUPABASE_URL    project URL
 *   SUPABASE_SERVICE_ROLE_KEY   server-only secret; never put it in a VITE_ variable
 *   TEST_ACCOUNT_PASSWORD       password given to every test account
 *   TEST_ACCOUNT_EMAIL_DOMAIN   optional, default "bongcun.test"
 *   ALLOW_TEST_ACCOUNTS=true    explicit opt-in so it cannot run by accident
 */
import { createClient } from "@supabase/supabase-js";

const need = (name) => {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing ${name}. Nothing was changed.`);
    process.exit(1);
  }
  return value;
};

if (process.env.NODE_ENV === "production" || process.env.ALLOW_TEST_ACCOUNTS !== "true") {
  console.error(
    "Refusing to run: set ALLOW_TEST_ACCOUNTS=true (and never use NODE_ENV=production).\n" +
      "These are test accounts with a shared password; they must not exist in production."
  );
  process.exit(1);
}

const url = need("NUXT_PUBLIC_SUPABASE_URL");
const serviceKey = need("SUPABASE_SERVICE_ROLE_KEY");
const password = need("TEST_ACCOUNT_PASSWORD");
const domain = process.env.TEST_ACCOUNT_EMAIL_DOMAIN || "bongcun.test";

// One account per role, so every permission level can be tried.
const ACCOUNTS = [
  { localPart: "superadmin", displayName: "Super Admin", role: "superAdmin" },
  { localPart: "admin", displayName: "Admin", role: "admin" },
  { localPart: "cashier", displayName: "Cashier", role: "cashier" },
  { localPart: "customer", displayName: "Customer", role: "customer" },
];

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const findUserByEmail = async (email) => {
  for (let page = 1; ; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    const match = data.users.find((user) => user.email === email);
    if (match || data.users.length < 1000) return match ?? null;
  }
};

for (const account of ACCOUNTS) {
  const email = `${account.localPart}@${domain}`;
  const existing = await findUserByEmail(email);

  let id;
  if (existing) {
    const { error } = await admin.auth.admin.updateUserById(existing.id, {
      password,
      email_confirm: true,
    });
    if (error) throw error;
    id = existing.id;
  } else {
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: account.displayName },
    });
    if (error) throw error;
    id = data.user.id;
  }

  // The signup trigger made the users row with role "customer". The service role
  // has no JWT uid, so the column-guard trigger lets the role be set here.
  const { error: roleError } = await admin.from("users").update({ role: account.role }).eq("id", id);
  if (roleError) throw roleError;

  console.log(`${existing ? "updated" : "created"}  ${email}  (${account.role})`);
}
console.log("Done. Sign out and back in after a role change: the role is read from the JWT.");
