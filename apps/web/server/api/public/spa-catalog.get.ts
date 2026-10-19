import { getSpaPublicCatalog } from "@bongcun/supabase/spa";
import { listBranches } from "@bongcun/supabase/users";

// The spa price list of a branch. Without a branch the first active one is used, so the page can ask
// for its data in one go; the answer says which branch that was.
export default defineEventHandler(async (event) => {
  const { branch } = await getValidatedQuery(event, branchQuerySchema.parse);
  return publicRead(event, async () => {
    const client = publicSupabase(event);
    const branchId = branch ?? (await listBranches(client))[0]?.id ?? null;
    return { branchId, catalog: await getSpaPublicCatalog(client, branchId) };
  });
});
