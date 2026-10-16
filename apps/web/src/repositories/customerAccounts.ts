// Staff side of the web accounts: find an account that has no customer record yet and link it to
// a counter customer (link_customer_account).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { UnlinkedAccount } from "@/types/account";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const searchUnlinkedAccounts = async (client: Client, text: string, limit = 8): Promise<UnlinkedAccount[]> => {
  if (text.trim().length < 2) return [];
  const rows = unwrap(await client.rpc("search_unlinked_accounts", { p_text: text, p_limit: limit }));
  return rows.map((row) => ({
    userId: row.user_id,
    fullName: row.full_name ?? "",
    phone: row.phone ?? "",
    email: row.email ?? "",
  }));
};

export const linkCustomerAccount = async (client: Client, customerId: string, userId: string): Promise<void> => {
  unwrap(await client.rpc("link_customer_account", { p_customer: customerId, p_user: userId }));
};

/** Error hints raised by link_customer_account. */
export const LINK_ERROR_HINTS = [
  "forbidden",
  "customer_not_found",
  "account_not_found",
  "customer_has_account",
  "account_has_customer",
] as const;
export type LinkErrorHint = (typeof LINK_ERROR_HINTS)[number];

export const linkErrorHint = (error: unknown): LinkErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return LINK_ERROR_HINTS.find((item) => item === hint) ?? null;
};
