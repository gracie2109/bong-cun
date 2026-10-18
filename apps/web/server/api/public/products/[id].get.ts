import { getSellableGroup } from "@bongcun/supabase/products";

// One product group with only its sellable variants; null when it does not exist.
export default defineEventHandler(async (event) => {
  const { id } = await getValidatedRouterParams(event, idParamSchema.parse);
  return publicRead(event, () => getSellableGroup(publicSupabase(event), id));
});
