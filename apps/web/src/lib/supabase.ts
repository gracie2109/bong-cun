import { useSupabaseClient } from "#imports";
import type { Database } from "@bongcun/supabase/db";

// Resolves the Supabase client of the current Nuxt app (cookie-based session,
// see @nuxtjs/supabase). On the client it can be called anywhere, including
// query functions and event handlers; on the server only inside a Nuxt context
// (component setup, plugin, route middleware).
export const supabaseClient = () => useSupabaseClient<Database>();
