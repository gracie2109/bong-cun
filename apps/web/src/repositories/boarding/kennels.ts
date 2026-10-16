// Kennels of one branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { Kennel, KennelFilter, KennelInput, KennelStatus } from "@bongcun/core/boarding";
import { unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

const toKennel = (value: unknown): Kennel => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    branchId: str(row.branch_id),
    kennelTypeId: str(row.kennel_type_id),
    kennelTypeName: str(row.kennel_type_name),
    code: str(row.code),
    name: strOrNull(row.name),
    status: str(row.status) as KennelStatus,
    isActive: row.is_active === true,
    sortOrder: Number(row.sort_order ?? 0),
  };
};

export const listKennels = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: KennelFilter = {}
): Promise<Page<Kennel>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_kennels", {
        p_branch: branchId,
        p_search: filter.search?.trim() || undefined,
        p_type: filter.typeId || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
      })
    )
  );
  const rows = Array.isArray(result.rows) ? result.rows : [];
  return { rows: rows.map(toKennel), total: Number(result.total ?? 0) };
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
