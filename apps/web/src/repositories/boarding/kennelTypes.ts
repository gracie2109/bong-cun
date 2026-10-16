// Kennel types: the catalog shared by every branch, with a shared price and optional branch prices.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { BranchKennelPrice, KennelPurpose, KennelType, KennelTypeFilter, KennelTypeInput } from "@/types/boarding";
import { unwrap, type Page, type PageParams } from "../shared";
import { asRecord, numOrNull, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

const strings = (value: unknown): string[] => (Array.isArray(value) ? value.map(String) : []);

const toBranchPrice = (value: unknown): BranchKennelPrice => {
  const row = asRecord(value);
  return {
    branchId: str(row.branch_id),
    branchName: str(row.branch_name),
    nightPrice: Number(row.night_price ?? 0),
    extraPetNightPrice: numOrNull(row.extra_pet_night_price),
  };
};

const toKennelType = (value: unknown): KennelType => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    name: str(row.name),
    description: strOrNull(row.description),
    photoUrl: strOrNull(row.photo_url),
    speciesIds: strings(row.species_ids),
    speciesNames: strings(row.species_names),
    maxWeightKg: numOrNull(row.max_weight_kg),
    maxPets: Number(row.max_pets ?? 1),
    purpose: str(row.purpose) as KennelPurpose,
    isActive: row.is_active === true,
    isPublic: row.is_public === true,
    sortOrder: Number(row.sort_order ?? 0),
    nightPrice: numOrNull(row.night_price),
    extraPetNightPrice: numOrNull(row.extra_pet_night_price),
    hasBranchPrice: row.has_branch_price === true,
    sharedNightPrice: numOrNull(row.shared_night_price),
    sharedExtraPetNightPrice: numOrNull(row.shared_extra_pet_night_price),
    branchPrices: Array.isArray(row.branch_prices) ? row.branch_prices.map(toBranchPrice) : [],
    kennelCount: Number(row.kennel_count ?? 0),
  };
};

export const listKennelTypes = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: KennelTypeFilter = {}
): Promise<Page<KennelType>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_kennel_types", {
        p_branch: branchId,
        p_search: filter.search?.trim() || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
        p_active_only: filter.activeOnly ?? false,
      })
    )
  );
  const rows = Array.isArray(result.rows) ? result.rows : [];
  return { rows: rows.map(toKennelType), total: Number(result.total ?? 0) };
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
