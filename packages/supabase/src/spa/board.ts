// The day view and the lookup behind a click on one of its tickets.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { dayBoardSchema } from "@bongcun/core/spa";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { listAppointments } from "./appointments";
import { toDayBoard } from "./mappers";
import type { Appointment, DayBoard } from "./types";

type Client = SupabaseClient<Database>;

export const getDayBoard = async (client: Client, branchId: string, date: string): Promise<DayBoard> =>
  toDayBoard(parseRpc("spa_day_board", dayBoardSchema, unwrap(await client.rpc("spa_day_board", { p_branch: branchId, p_date: date }))));

/** One appointment by its code (the day board only knows the code of a ticket's appointment). */
export const findAppointment = async (client: Client, branchId: string, code: string): Promise<Appointment | null> => {
  const { rows } = await listAppointments(client, branchId, { pageIndex: 1, pageSize: 5 }, { search: code });
  return rows.find((row) => row.code === code) ?? null;
};

