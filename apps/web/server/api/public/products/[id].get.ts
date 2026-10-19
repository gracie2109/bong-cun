import { getSellableGroup } from "@bongcun/supabase/products";
import { fetchVariantAvailability } from "@bongcun/supabase/shop";

// One product group with only its sellable variants (null when it does not exist), and how many of
// each variant can be bought now, so the page needs one request.
export default defineEventHandler(async (event) => {
  const { id } = await getValidatedRouterParams(event, idParamSchema.parse);
  return publicRead(event, async () => {
    const client = publicSupabase(event);
    const group = await getSellableGroup(client, id);
    const variantIds = group?.variants.map((variant) => variant.id) ?? [];
    const stock = variantIds.length > 0 ? await fetchVariantAvailability(client, variantIds) : {};
    return { group, stock };
  });
});
