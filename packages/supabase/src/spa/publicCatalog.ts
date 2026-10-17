// The public spa price list (spa_public_catalog): readable without signing in.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { publicCatalogSchema, type SpaCatalog } from "@bongcun/core/spa";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toSpaCatalog } from "./mappers";

type Client = SupabaseClient<Database>;

export const getSpaPublicCatalog = async (client: Client, branchId: string | null): Promise<SpaCatalog> =>
  toSpaCatalog(
    parseRpc("spa_public_catalog", publicCatalogSchema, unwrap(await client.rpc("spa_public_catalog", { p_branch: branchId })))
  );
