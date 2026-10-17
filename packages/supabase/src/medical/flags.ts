// Warning flags for the spa and pet hotel counters (see 20261021070100_pet_health_flags.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { PetHealthFlags } from "@bongcun/core/medical";
import { petHealthFlagsSchema } from "@bongcun/core/medical";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toPetHealthFlags } from "./mappers";

type Client = SupabaseClient<Database>;

export const getPetHealthFlags = async (client: Client, petIds: string[]): Promise<Record<string, PetHealthFlags>> => {
  const raw = unwrap(await client.rpc("pet_health_flags", { p_pet_ids: petIds }));
  return toPetHealthFlags(parseRpc("pet_health_flags", petHealthFlagsSchema, raw) ?? {});
};
