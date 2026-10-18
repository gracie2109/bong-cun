import { getSpaPublicCatalog } from "@bongcun/supabase/spa";

// The spa price list of a branch (no branch = shared prices only).
export default defineEventHandler(async (event) => {
  const { branch } = await getValidatedQuery(event, branchQuerySchema.parse);
  return publicRead(event, () => getSpaPublicCatalog(publicSupabase(event), branch ?? null));
});
