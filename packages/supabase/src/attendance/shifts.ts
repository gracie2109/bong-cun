// Shift templates, branch rules and the roster.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  assignShiftResultSchema,
  attendanceRulesSchema,
  copyWeekResultSchema,
  rosterSchema,
  shiftTemplateRowSchema,
} from "@bongcun/core/attendance";
import type {
  AssignShiftInput,
  AttendanceRules,
  AttendanceRulesInput,
  CopyWeekInput,
  Roster,
  ShiftTemplate,
  ShiftTemplateInput,
  UpdateShiftInput,
} from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toAttendanceRules, toRoster, toShiftTemplate } from "./mappers";

type Client = SupabaseClient<Database>;

export const getAttendanceRules = async (client: Client, branchId: string): Promise<AttendanceRules> =>
  toAttendanceRules(parseRpc("attendance_rules", attendanceRulesSchema, unwrap(await client.rpc("attendance_rules", { p_branch: branchId }))));

export const saveAttendanceRules = async (client: Client, branchId: string, input: AttendanceRulesInput): Promise<AttendanceRules> => {
  const raw = unwrap(
    await client.rpc("save_attendance_settings", {
      p_branch: branchId,
      p: {
        late_grace_minutes: input.lateGraceMinutes,
        early_grace_minutes: input.earlyGraceMinutes,
        checkin_early_minutes: input.checkinEarlyMinutes,
        overtime_min_minutes: input.overtimeMinMinutes,
        allow_unscheduled: input.allowUnscheduled,
        review_after_hours: input.reviewAfterHours,
      },
    })
  );
  return toAttendanceRules(parseRpc("save_attendance_settings", attendanceRulesSchema, raw));
};

export const listShiftTemplates = async (client: Client, branchId: string, includeInactive = false): Promise<ShiftTemplate[]> => {
  const raw = unwrap(await client.rpc("list_shift_templates", { p_branch: branchId, p_include_inactive: includeInactive }));
  return (raw ?? []).map((row) => toShiftTemplate(parseRpc("list_shift_templates", shiftTemplateRowSchema, row)));
};

export const saveShiftTemplate = async (client: Client, branchId: string, input: ShiftTemplateInput): Promise<string> =>
  unwrap(
    await client.rpc("save_shift_template", {
      p_branch: branchId,
      p: {
        id: input.id,
        name: input.name,
        start_time: input.startTime,
        end_time: input.endTime,
        break_minutes: input.breakMinutes,
        color: input.color,
        sort_order: input.sortOrder,
      },
    })
  );

export const setShiftTemplateActive = async (client: Client, id: string, active: boolean): Promise<void> => {
  unwrap(await client.rpc("set_shift_template_active", { p_id: id, p_active: active }));
};

export const getShiftRoster = async (client: Client, branchId: string, from: string, to: string): Promise<Roster> =>
  toRoster(parseRpc("shift_roster", rosterSchema, unwrap(await client.rpc("shift_roster", { p_branch: branchId, p_from: from, p_to: to }))));

/** Returns the new shift's id and `"on_leave"` when the person has approved leave then. */
export const assignShift = async (client: Client, input: AssignShiftInput) => {
  const raw = unwrap(
    await client.rpc("assign_shift", {
      p_branch: input.branchId,
      p_user: input.userId,
      p_date: input.workDate,
      p_template: input.templateId ?? undefined,
      p_start: input.startTime ?? undefined,
      p_end: input.endTime ?? undefined,
      p_break: input.breakMinutes ?? undefined,
      p_note: input.note ?? undefined,
      p_reason: input.reason ?? undefined,
    })
  );
  return parseRpc("assign_shift", assignShiftResultSchema, raw);
};

export const updateShiftAssignment = async (client: Client, input: UpdateShiftInput): Promise<void> => {
  const { id, workDate, templateId, startTime, endTime, breakMinutes, note, reason } = input;
  const patch = {
    work_date: workDate,
    template_id: templateId,
    start_time: startTime,
    end_time: endTime,
    break_minutes: breakMinutes,
    note,
  };
  // Only the keys the caller set: the function reads `p ? 'key'` to tell "leave it" from "clear it".
  const p = Object.fromEntries(Object.entries(patch).filter(([, value]) => value !== undefined));
  unwrap(await client.rpc("update_shift_assignment", { p_id: id, p, p_reason: reason ?? undefined }));
};

export const removeShiftAssignment = async (client: Client, id: string, reason?: string | null): Promise<void> => {
  unwrap(await client.rpc("remove_shift_assignment", { p_id: id, p_reason: reason ?? undefined }));
};

export const copyRosterWeek = async (client: Client, input: CopyWeekInput) =>
  parseRpc(
    "copy_roster_week",
    copyWeekResultSchema,
    unwrap(
      await client.rpc("copy_roster_week", {
        p_branch: input.branchId,
        p_from_monday: input.fromMonday,
        p_to_monday: input.toMonday,
        p_overwrite: input.overwrite ?? false,
        p_reason: input.reason ?? undefined,
      })
    )
  );
