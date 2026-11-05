// The timesheet: totals per person, the monthly grid and my own hours.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { myTimesheetSchema, timesheetGridSchema, timesheetListSchema } from "@bongcun/core/attendance";
import type { MyTimesheet, TimesheetFilter, TimesheetGrid, TimesheetList } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toMyTimesheet, toTimesheetGrid, toTimesheetList } from "./mappers";

type Client = SupabaseClient<Database>;

export const getTimesheet = async (client: Client, filter: TimesheetFilter, limit: number, offset: number): Promise<TimesheetList> => {
  const raw = unwrap(
    await client.rpc("report_timesheet", {
      p_branch: filter.branchId,
      p_from: filter.from,
      p_to: filter.to,
      p_search: filter.search,
      p_limit: limit,
      p_offset: offset,
    })
  );
  return toTimesheetList(parseRpc("report_timesheet", timesheetListSchema, raw));
};

export const getTimesheetGrid = async (client: Client, branchId: string, month: string): Promise<TimesheetGrid> =>
  toTimesheetGrid(parseRpc("report_timesheet_grid", timesheetGridSchema, unwrap(await client.rpc("report_timesheet_grid", { p_branch: branchId, p_month: month }))));

export const getMyTimesheet = async (client: Client, from: string, to: string): Promise<MyTimesheet> =>
  toMyTimesheet(parseRpc("my_timesheet", myTimesheetSchema, unwrap(await client.rpc("my_timesheet", { p_from: from, p_to: to }))));
