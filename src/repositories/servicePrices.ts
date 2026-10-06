// Price of a service for a pet at a given weight class.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

export type ServicePrice = {
  id: string;
  petId: string;
  serviceId: string;
  weightId: string;
  price: number;
};

export type ServicePriceInput = { weightId: string; price: number | string | null };

export const listServicePrices = async (
  client: Client,
  filter: { petId: string; serviceId?: string }
): Promise<ServicePrice[]> => {
  let query = client.from("pet_service_prices").select("*").eq("pet_id", filter.petId);
  if (filter.serviceId) query = query.eq("service_id", filter.serviceId);

  return unwrap(await query).map((row) => ({
    id: row.id,
    petId: row.pet_id,
    serviceId: row.service_id,
    weightId: row.weight_id,
    price: row.price,
  }));
};

/** Replaces the weight prices of one service for one pet in a single transaction. */
export const saveServicePrices = async (
  client: Client,
  args: { petId: string; serviceId: string; rows: ServicePriceInput[] }
): Promise<void> => {
  const { error } = await client.rpc("save_service_prices", {
    p_pet_id: args.petId,
    p_service_id: args.serviceId,
    p_rows: args.rows.map((row) => ({ weight_id: row.weightId, price: row.price })),
  });
  if (error) throw error;
};
