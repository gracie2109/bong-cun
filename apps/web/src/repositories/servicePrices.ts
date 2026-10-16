// Price of a service for a species at a weight bracket, shared or overridden per branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

export type ServicePrice = {
  id: string;
  speciesId: string;
  serviceId: string;
  bracketId: string;
  /** null = the shared price; otherwise the override for that branch. */
  branchId: string | null;
  price: number;
};

export type ServicePriceInput = { bracketId: string; price: number | string | null };

export type ServicePriceFilter = {
  speciesId: string;
  serviceId?: string;
  /** Rows to read: the shared prices (null) or one branch's overrides. */
  branchId: string | null;
};

export const listServicePrices = async (
  client: Client,
  filter: ServicePriceFilter
): Promise<ServicePrice[]> => {
  let query = client.from("pet_service_prices").select("*").eq("species_id", filter.speciesId);
  if (filter.serviceId) query = query.eq("service_id", filter.serviceId);
  query = filter.branchId ? query.eq("branch_id", filter.branchId) : query.is("branch_id", null);

  return unwrap(await query).map((row) => ({
    id: row.id,
    speciesId: row.species_id,
    serviceId: row.service_id,
    bracketId: row.bracket_id,
    branchId: row.branch_id,
    price: row.price,
  }));
};

/** Replaces the prices of one service for one species (shared or one branch) in a single transaction. */
export const saveServicePrices = async (
  client: Client,
  args: {
    speciesId: string;
    serviceId: string;
    branchId: string | null;
    rows: ServicePriceInput[];
  }
): Promise<void> => {
  const { error } = await client.rpc("save_service_prices", {
    p_species_id: args.speciesId,
    p_service_id: args.serviceId,
    p_branch_id: args.branchId ?? undefined,
    p_rows: args.rows.map((row) => ({ bracket_id: row.bracketId, price: row.price })),
  });
  if (error) throw error;
};

/** The price for an animal of a given weight: branch override, else the shared price, else null. */
export const getServicePrice = async (
  client: Client,
  args: { speciesId: string; serviceId: string; weightKg: number; branchId?: string | null }
): Promise<number | null> =>
  unwrap(
    await client.rpc("get_service_price", {
      p_species_id: args.speciesId,
      p_service_id: args.serviceId,
      p_weight_kg: args.weightKg,
      p_branch_id: args.branchId ?? undefined,
    })
  );
