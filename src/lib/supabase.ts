import { useSupabaseClient } from "#imports";
import type { Database } from "@/types/database.types";

// Resolves the Supabase client of the current Nuxt app (cookie-based session,
// see @nuxtjs/supabase). On the client it can be called anywhere, including
// query functions and event handlers; on the server only inside a Nuxt context
// (component setup, plugin, route middleware).
export const supabaseClient = () => useSupabaseClient<Database>();
