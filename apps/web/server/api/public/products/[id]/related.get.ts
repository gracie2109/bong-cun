import { listRelatedGroups } from "@bongcun/supabase/shop";

export default defineEventHandler(async (event) => {
  const { id } = await getValidatedRouterParams(event, idParamSchema.parse);
  return publicRead(event, () => listRelatedGroups(publicSupabase(event), id));
});
