// The vaccine / deworming catalog shared by every branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { VaccineKind, VaccineType, VaccineTypeFilter, VaccineTypeInput } from "@/types/medical";
import { unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { asRecord, numOrNull, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

const strings = (value: unknown): string[] => (Array.isArray(value) ? value.map(String) : []);

const toVaccineType = (value: unknown): VaccineType => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    name: str(row.name),
    kind: str(row.kind) as VaccineKind,
    speciesIds: strings(row.species_ids),
    speciesNames: strings(row.species_names),
    productId: strOrNull(row.product_id),
    productName: strOrNull(row.product_name),
    productUnit: strOrNull(row.product_unit),
    stockQty: numOrNull(row.stock_qty),
    seriesDoses: Number(row.series_doses ?? 1),
    seriesIntervalDays: numOrNull(row.series_interval_days),
    boosterIntervalDays: numOrNull(row.booster_interval_days),
    minAgeWeeks: numOrNull(row.min_age_weeks),
    isActive: row.is_active === true,
    sortOrder: Number(row.sort_order ?? 0),
  };
};

/** `branchId` adds the unexpired stock of each type's product at that branch. */
export const listVaccineTypes = async (
  client: Client,
  page: PageParams,
  filter: VaccineTypeFilter = {},
  branchId?: string
): Promise<Page<VaccineType>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_vaccine_types", {
        p_search: filter.search?.trim() || undefined,
        p_kind: filter.kind || undefined,
        p_species: filter.speciesId || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
        p_branch: branchId || undefined,
        p_active_only: filter.activeOnly ?? false,
      })
    )
  );
  const rows = Array.isArray(result.rows) ? result.rows : [];
  return { rows: rows.map(toVaccineType), total: Number(result.total ?? 0) };
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
