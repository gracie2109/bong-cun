// "Clinic only" groups are hidden from the online shop (see 20261021070200_clinic_only_products.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

export const getClinicOnly = async (client: Client, groupId: string): Promise<boolean> => {
  const { data, error } = await client.from("product_groups").select("clinic_only").eq("id", groupId).maybeSingle();
  if (error) throw error;
  return data?.clinic_only === true;
};

export const setClinicOnly = async (client: Client, groupId: string, value: boolean): Promise<void> => {
  unwrap(await client.rpc("set_product_group_clinic_only", { p_group: groupId, p_value: value }));
};
