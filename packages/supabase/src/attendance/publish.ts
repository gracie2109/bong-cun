// Publishing a week, the "no shifts this week" declaration, exemptions and the list of people who have not registered.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  copyPersonResultSchema,
  exemptionListSchema,
  publishResultSchema,
  registrationStatusSchema,
  weekStatusSchema,
  weeksWithShiftsSchema,
} from "@bongcun/core/attendance";
import type { DeclareNoShiftsInput, Exemption, PublishResult, RegistrationStatus, WeekStatus, WeekWithShifts } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toExemptions, toRegistrationStatus, toWeekStatus, toWeeksWithShifts } from "./publishMappers";

type Client = SupabaseClient<Database>;

export const getWeekStatus = async (client: Client, branchId: string, monday: string): Promise<WeekStatus> =>
  toWeekStatus(
    parseRpc("schedule_week_status", weekStatusSchema, unwrap(await client.rpc("schedule_week_status", { p_branch: branchId, p_monday: monday })))
  );

export const getRegistrationStatus = async (client: Client, branchId: string, monday: string): Promise<RegistrationStatus> =>
  toRegistrationStatus(
    parseRpc("registration_status", registrationStatusSchema, unwrap(await client.rpc("registration_status", { p_branch: branchId, p_monday: monday })))
  );

export const publishScheduleWeek = async (client: Client, branchId: string, monday: string, rejectNote?: string): Promise<PublishResult> =>
  parseRpc(
    "publish_schedule_week",
    publishResultSchema,
    unwrap(await client.rpc("publish_schedule_week", { p_branch: branchId, p_monday: monday, p_reject_note: rejectNote }))
  );

export const declareNoShifts = async (client: Client, input: DeclareNoShiftsInput): Promise<void> => {
  unwrap(await client.rpc("declare_no_shifts", { p_branch: input.branchId, p_monday: input.monday, p_reason: input.reason ?? undefined }));
};

export const withdrawNoShifts = async (client: Client, branchId: string, monday: string): Promise<void> => {
  unwrap(await client.rpc("withdraw_no_shifts", { p_branch: branchId, p_monday: monday }));
};

/** "Like last week" for one person. */
export const assignToPreviousWeek = async (client: Client, branchId: string, monday: string, userId: string, reason?: string | null) =>
  parseRpc(
    "assign_to_previous_week",
    copyPersonResultSchema,
    unwrap(await client.rpc("assign_to_previous_week", { p_branch: branchId, p_monday: monday, p_user: userId, p_reason: reason ?? undefined }))
  );

export const listRegistrationExemptions = async (client: Client, branchId: string): Promise<Exemption[]> =>
  toExemptions(
    parseRpc("list_registration_exemptions", exemptionListSchema, unwrap(await client.rpc("list_registration_exemptions", { p_branch: branchId })))
  );

export const setRegistrationExemption = async (client: Client, branchId: string, userId: string, exempt: boolean, note?: string | null): Promise<void> => {
  unwrap(await client.rpc("set_registration_exemption", { p_branch: branchId, p_user: userId, p_exempt: exempt, p_note: note ?? undefined }));
};

/** The future weeks that already have shifts: what switching publishing on would hide. */
export const listWeeksWithShifts = async (client: Client, branchId: string): Promise<WeekWithShifts[]> =>
  toWeeksWithShifts(parseRpc("weeks_with_shifts", weeksWithShiftsSchema, unwrap(await client.rpc("weeks_with_shifts", { p_branch: branchId }))));
