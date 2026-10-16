import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

// ------------------------------------------------------------ cart helpers
/** A customer's current pets, with species and latest weight for by-weight prices. */
export type CustomerPet = {
  id: string;
  name: string;
  speciesId: string;
  speciesName: string;
  weightKg: number | null;
};

export const listCustomerPets = async (client: Client, customerId: string): Promise<CustomerPet[]> => {
  const links = unwrap(
    await client.from("pet_owners").select("pet_id").eq("customer_id", customerId).is("to_date", null)
  );
  const ids = links.map((link) => link.pet_id);
  if (ids.length === 0) return [];
  const rows = unwrap(
    await client.from("pet_overview").select("*").in("id", ids).eq("status", "active").order("name")
  );
  return rows.map((row) => ({
    id: row.id ?? "",
    name: row.name ?? "",
    speciesId: row.species_id ?? "",
    speciesName: row.species_name ?? "",
    weightKg: row.weight_kg,
  }));
};

/** Price preview for a by-weight service; the sale itself is priced again by create_invoice. */
export const previewServicePrice = async (
  client: Client,
  args: { speciesId: string; serviceId: string; weightKg: number; branchId: string }
): Promise<number | null> => {
  const { data, error } = await client.rpc("get_service_price", {
    p_species_id: args.speciesId,
    p_service_id: args.serviceId,
    p_weight_kg: args.weightKg,
    p_branch_id: args.branchId,
  });
  if (error) throw error;
  return data ?? null;
};

/** Combos that can be sold now: active, shown (status 1) and priced. Combos sell at their fixed price. */
export type SellableCombo = { id: string; name: string; price: number; speciesIds: string[] };

export const listSellableCombos = async (client: Client): Promise<SellableCombo[]> => {
  const rows = unwrap(
    await client
      .from("pet_service_combos")
      .select("id, name, price, combo_species(species_id)")
      .eq("is_active", true)
      .eq("status", 1)
      .not("price", "is", null)
      .order("name")
  ) as { id: string; name: string; price: number | null; combo_species: { species_id: string }[] }[];
  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    price: row.price ?? 0,
    speciesIds: row.combo_species.map((link) => link.species_id),
  }));
};
