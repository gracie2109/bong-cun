// The public pet hotel page (boarding_public_catalog): readable without signing in.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { publicCatalogSchema } from "@bongcun/core/boarding";
import type { BoardingWebCatalog } from "@bongcun/core/boarding";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toPublicCatalog } from "./mappers";

type Client = SupabaseClient<Database>;

export const getBoardingPublicCatalog = async (client: Client, branchId: string | null = null): Promise<BoardingWebCatalog> => {
  const raw = unwrap(await client.rpc("boarding_public_catalog", { p_branch: branchId }));
  return toPublicCatalog(parseRpc("boarding_public_catalog", publicCatalogSchema, raw));
};
