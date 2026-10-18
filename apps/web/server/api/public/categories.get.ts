import { listProductCategories } from "@bongcun/supabase/products";

export default defineEventHandler(async (event) => {
  const query = await getValidatedQuery(event, categoriesQuerySchema.parse);
  return publicRead(event, () =>
    listProductCategories(
      publicSupabase(event),
      { pageIndex: query.page, pageSize: query.pageSize },
      { rootsOnly: query.rootsOnly }
    )
  );
});
