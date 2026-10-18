import type { H3Event } from "h3";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";

let client: SupabaseClient<Database> | null = null;

/**
 * An anonymous Supabase client that lives only on the server. The public /api/public routes read
 * through it, so the browser talks to this site and never sees the database's RPC names or URL.
 */
export const publicSupabase = (event: H3Event): SupabaseClient<Database> => {
  if (client) return client;
  const config = useRuntimeConfig(event).public.supabase as { url?: string; key?: string; publishableKey?: string } | undefined;
  const key = config?.key ?? config?.publishableKey;
  if (!config?.url || !key) throw createError({ statusCode: 503, statusMessage: "Catalog is not configured" });
  client = createClient<Database>(config.url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  return client;
};
