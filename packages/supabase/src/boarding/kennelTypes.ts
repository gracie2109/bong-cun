// Kennel types: the catalog shared by every branch, with a shared price and optional branch prices.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { kennelTypePageSchema } from "@bongcun/core/boarding";
import type { KennelType, KennelTypeFilter, KennelTypeInput } from "@bongcun/core/boarding";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toKennelType } from "./mappers";

type Client = SupabaseClient<Database>;

export const listKennelTypes = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: KennelTypeFilter = {}
): Promise<Page<KennelType>> => {
  const raw = unwrap(
    await client.rpc("list_kennel_types", {
      p_branch: branchId,
      p_search: filter.search?.trim() || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
      p_active_only: filter.activeOnly ?? false,
    })
  );
  const result = parseRpc("list_kennel_types", kennelTypePageSchema, raw);
  return { rows: (result.rows ?? []).map(toKennelType), total: result.total };
};

export const saveKennelType = async (client: Client, input: KennelTypeInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_kennel_type", {
      p: {
        name: input.name,
        description: input.description,
        photo_url: input.photoUrl,
        species_ids: input.speciesIds,
        max_weight_kg: input.maxWeightKg,
        max_pets: input.maxPets,
        is_active: input.isActive,
        is_public: input.isPublic,
        sort_order: input.sortOrder,
        night_price: input.sharedNightPrice,
        extra_pet_night_price: input.sharedExtraPetNightPrice,
        branch_prices: input.branchPrices.map((price) => ({
          branch_id: price.branchId,
          night_price: price.nightPrice,
          extra_pet_night_price: price.extraPetNightPrice,
        })),
      },
      p_id: id,
    })
  );
