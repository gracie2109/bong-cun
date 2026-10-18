import { listShopGroups } from "@bongcun/supabase/shop";

// One page of the shop list, narrowed like the URL filters of /products.
export default defineEventHandler(async (event) => {
  const query = await getValidatedQuery(event, productsQuerySchema.parse);
  return publicRead(event, () =>
    listShopGroups(
      publicSupabase(event),
      { pageIndex: query.page, pageSize: query.pageSize },
      { search: query.search, categoryId: query.category ?? null, brandId: query.brand ?? null, sort: query.sort }
    )
  );
});
