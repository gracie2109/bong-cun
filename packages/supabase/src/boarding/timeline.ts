// The kennel calendar and moving a pet to another kennel.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { timelineSchema } from "@bongcun/core/boarding";
import type { BoardingTimeline } from "@bongcun/core/boarding";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toTimeline } from "./mappers";

type Client = SupabaseClient<Database>;

export const getBoardingTimeline = async (client: Client, branchId: string, from: string, days: number): Promise<BoardingTimeline> => {
  const raw = unwrap(await client.rpc("boarding_timeline", { p_branch: branchId, p_from: from, p_days: days }));
  return toTimeline(parseRpc("boarding_timeline", timelineSchema, raw));
};

export const moveBoardingPet = async (client: Client, stayPetId: string, kennelId: string): Promise<void> => {
  unwrap(await client.rpc("move_boarding_pet", { p_stay_pet: stayPetId, p_kennel: kennelId }));
};
