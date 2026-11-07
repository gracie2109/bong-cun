// Shift registration: the window settings, the staff page's board, and sending or cancelling requests.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  myShiftRequestsSchema,
  registrationBoardSchema,
  registrationRulesSchema,
  submitResultSchema,
} from "@bongcun/core/attendance";
import type {
  MyShiftRequestListed,
  RegistrationBoard,
  RegistrationRules,
  RegistrationSettingsInput,
  SubmitRequestsInput,
  SubmitResult,
} from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toMyShiftRequestListed, toRegistrationBoard, toRegistrationRules, toSubmitResult } from "./registrationMappers";

type Client = SupabaseClient<Database>;

export const getRegistrationRules = async (client: Client, branchId: string): Promise<RegistrationRules> =>
  toRegistrationRules(
    parseRpc("shift_registration_rules", registrationRulesSchema, unwrap(await client.rpc("shift_registration_rules", { p_branch: branchId })))
  );

export const saveRegistrationSettings = async (client: Client, branchId: string, input: RegistrationSettingsInput): Promise<RegistrationRules> =>
  toRegistrationRules(
    parseRpc(
      "save_shift_registration_settings",
      registrationRulesSchema,
      unwrap(
        await client.rpc("save_shift_registration_settings", {
          p_branch: branchId,
          p: {
            is_open: input.isOpen,
            weeks_ahead: input.weeksAhead,
            close_days_before: input.closeDaysBefore,
            max_shifts_per_week: input.maxShiftsPerWeek,
            staff_note: input.staffNote,
          },
        })
      )
    )
  );

export const getRegistrationBoard = async (client: Client, branchId: string, monday: string): Promise<RegistrationBoard> =>
  toRegistrationBoard(
    parseRpc(
      "shift_registration_board",
      registrationBoardSchema,
      unwrap(await client.rpc("shift_registration_board", { p_branch: branchId, p_monday: monday }))
    )
  );

export const submitShiftRequests = async (client: Client, input: SubmitRequestsInput): Promise<SubmitResult> =>
  toSubmitResult(
    parseRpc(
      "submit_shift_requests",
      submitResultSchema,
      unwrap(
        await client.rpc("submit_shift_requests", {
          p_branch: input.branchId,
          p_monday: input.monday,
          p_items: input.cells.map((cell) => ({ work_date: cell.workDate, template_id: cell.templateId })),
          p_note: input.note ?? undefined,
        })
      )
    )
  );

export const cancelShiftRequest = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("cancel_shift_request", { p_id: id }));
};

export const getMyShiftRequests = async (client: Client, from: string, to: string): Promise<MyShiftRequestListed[]> =>
  parseRpc("my_shift_requests", myShiftRequestsSchema, unwrap(await client.rpc("my_shift_requests", { p_from: from, p_to: to }))).map(
    toMyShiftRequestListed
  );
