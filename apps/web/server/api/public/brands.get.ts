import { listProductBrands } from "@bongcun/supabase/products";

export default defineEventHandler(async (event) => {
  const query = await getValidatedQuery(event, pageQuerySchema.parse);
  return publicRead(event, () =>
    listProductBrands(publicSupabase(event), { pageIndex: query.page, pageSize: query.pageSize })
  );
});
