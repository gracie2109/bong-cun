// Kennels of one branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { kennelPageSchema } from "@bongcun/core/boarding";
import type { Kennel, KennelFilter, KennelInput, KennelStatus } from "@bongcun/core/boarding";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toKennel } from "./mappers";

type Client = SupabaseClient<Database>;

export const listKennels = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: KennelFilter = {}
): Promise<Page<Kennel>> => {
  const raw = unwrap(
    await client.rpc("list_kennels", {
      p_branch: branchId,
      p_search: filter.search?.trim() || undefined,
      p_type: filter.typeId || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
    })
  );
  const result = parseRpc("list_kennels", kennelPageSchema, raw);
  return { rows: (result.rows ?? []).map(toKennel), total: result.total };
};

export const saveKennel = async (client: Client, input: KennelInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_kennel", {
      p: {
        branch_id: input.branchId,
        kennel_type_id: input.kennelTypeId,
        code: input.code,
        name: input.name,
        is_active: input.isActive,
        sort_order: input.sortOrder,
      },
      p_id: id,
    })
  );

export const setKennelStatus = async (client: Client, id: string, status: KennelStatus): Promise<void> => {
  unwrap(await client.rpc("set_kennel_status", { p_id: id, p_status: status }));
};
