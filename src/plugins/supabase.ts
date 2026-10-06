import { createClient } from "@supabase/supabase-js";
import { env } from "@/config/env";
import type { Database } from "@/types/database.types";

// Factory, not just a singleton: Nuxt will build one client per request
// (@supabase/ssr) and repositories receive whichever client they are given.
export const createSupabaseClient = () =>
  createClient<Database>(env.supabaseUrl, env.supabasePublishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: "pkce",
    },
  });

export const supabase = createSupabaseClient();
