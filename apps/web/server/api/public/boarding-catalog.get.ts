import { getBoardingPublicCatalog } from "@bongcun/supabase/boarding";

// The pet hotel price list (first active branch).
export default defineEventHandler((event) =>
  publicRead(event, () => getBoardingPublicCatalog(publicSupabase(event)))
);
