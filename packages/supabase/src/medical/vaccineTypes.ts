// The vaccine / deworming catalog shared by every branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { vaccineTypePageSchema } from "@bongcun/core/medical";
import type { VaccineType, VaccineTypeFilter, VaccineTypeInput } from "@bongcun/core/medical";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toVaccineType } from "./mappers";

type Client = SupabaseClient<Database>;

/** `branchId` adds the unexpired stock of each type's product at that branch. */
export const listVaccineTypes = async (
  client: Client,
  page: PageParams,
  filter: VaccineTypeFilter = {},
  branchId?: string
): Promise<Page<VaccineType>> => {
  const raw = unwrap(
    await client.rpc("list_vaccine_types", {
      p_search: filter.search?.trim() || undefined,
      p_kind: filter.kind || undefined,
      p_species: filter.speciesId || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
      p_branch: branchId || undefined,
      p_active_only: filter.activeOnly ?? false,
    })
  );
  const result = parseRpc("list_vaccine_types", vaccineTypePageSchema, raw);
  return { rows: (result.rows ?? []).map(toVaccineType), total: result.total };
};

export const saveVaccineType = async (client: Client, input: VaccineTypeInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_vaccine_type", {
      p: {
        name: input.name,
        kind: input.kind,
        species_ids: input.speciesIds,
        product_id: input.productId,
        series_doses: input.seriesDoses,
        series_interval_days: input.seriesIntervalDays,
        booster_interval_days: input.boosterIntervalDays,
        min_age_weeks: input.minAgeWeeks,
        is_active: input.isActive,
        sort_order: input.sortOrder,
      },
      p_id: id,
    })
  );
