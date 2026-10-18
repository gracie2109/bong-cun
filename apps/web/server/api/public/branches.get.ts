import { listBranches } from "@bongcun/supabase/users";

// Active branches, for the branch pickers of the spa price list and booking.
export default defineEventHandler((event) => publicRead(event, () => listBranches(publicSupabase(event))));
