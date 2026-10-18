import { fetchVariantAvailability } from "@bongcun/supabase/shop";

// How many of each variant can be bought now (capped at 99), for `?ids=a,b,c`.
export default defineEventHandler(async (event) => {
  const { ids } = await getValidatedQuery(event, stockQuerySchema.parse);
  return publicRead(event, () => fetchVariantAvailability(publicSupabase(event), ids));
});
