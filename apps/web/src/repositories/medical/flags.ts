// Warning flags for the spa and pet hotel counters (see 20261021070100_pet_health_flags.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { PetHealthFlags } from "@bongcun/core/medical";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, strOrNull } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const getPetHealthFlags = async (client: Client, petIds: string[]): Promise<Record<string, PetHealthFlags>> => {
  const raw = asRecord(unwrap(await client.rpc("pet_health_flags", { p_pet_ids: petIds })));
  const flags: Record<string, PetHealthFlags> = {};
  for (const [petId, value] of Object.entries(raw)) {
    const row = asRecord(value);
    flags[petId] = { contagious: row.contagious === true, vaccineOverdue: row.vaccine_overdue === true, allergies: strOrNull(row.allergies) };
  }
  return flags;
};
