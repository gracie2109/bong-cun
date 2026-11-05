// Self service clock in/out and the "today" and "my schedule" views.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  clockInResultSchema,
  clockOutResultSchema,
  clockStatusSchema,
  mySchedulePartSchema,
  todayBoardSchema,
} from "@bongcun/core/attendance";
import type { ClockInInput, ClockInResult, ClockOutResult, ClockStatus, MySchedule, TodayBoard } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toClockStatus, toMySchedule, toTodayBoard } from "./mappers";

type Client = SupabaseClient<Database>;

export const getClockStatus = async (client: Client): Promise<ClockStatus> =>
  toClockStatus(parseRpc("clock_status", clockStatusSchema, unwrap(await client.rpc("clock_status"))));

export const clockIn = async (client: Client, input: ClockInInput): Promise<ClockInResult> => {
  const raw = unwrap(
    await client.rpc("clock_in", { p_branch: input.branchId, p_note: input.note, p_unscheduled_ok: input.unscheduledOk ?? false })
  );
  const row = parseRpc("clock_in", clockInResultSchema, raw);
  return {
    entryId: row.entry_id,
    assignmentId: row.assignment_id ?? null,
    shiftName: row.shift_name ?? null,
    lateMinutes: row.late_minutes,
    onLeave: row.warning === "on_leave",
  };
};

export const clockOut = async (client: Client, note?: string): Promise<ClockOutResult> => {
  const row = parseRpc("clock_out", clockOutResultSchema, unwrap(await client.rpc("clock_out", { p_note: note })));
  return { entryId: row.entry_id, workedMinutes: row.worked_minutes, earlyMinutes: row.early_minutes, overtimeMinutes: row.overtime_minutes };
};

export const getAttendanceToday = async (client: Client, branchId: string, date?: string): Promise<TodayBoard> =>
  toTodayBoard(parseRpc("attendance_today", todayBoardSchema, unwrap(await client.rpc("attendance_today", { p_branch: branchId, p_date: date }))));

export const getMySchedule = async (client: Client, from: string, to: string): Promise<MySchedule> =>
  toMySchedule(parseRpc("my_schedule", mySchedulePartSchema, unwrap(await client.rpc("my_schedule", { p_from: from, p_to: to }))));
