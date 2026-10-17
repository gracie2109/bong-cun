// The day board of kennels.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { boardSchema } from "@bongcun/core/boarding";
import type { DayBoard } from "@bongcun/core/boarding";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toDayBoard } from "./mappers";

type Client = SupabaseClient<Database>;

/** Every kennel of the branch with what is in it on `date` (yyyy-MM-dd). */
export const getBoardingBoard = async (client: Client, branchId: string, date: string): Promise<DayBoard> => {
  const raw = unwrap(await client.rpc("boarding_board", { p_branch: branchId, p_date: date }));
  return toDayBoard(parseRpc("boarding_board", boardSchema, raw));
};
