// Leave requests: filing, withdrawing, deciding, the lists and the yearly balance.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  decideLeaveResultSchema,
  leaveBalanceSchema,
  leaveListSchema,
  myLeaveSchema,
  requestLeaveResultSchema,
} from "@bongcun/core/attendance";
import type {
  DecideLeaveInput,
  LeaveBalance,
  LeaveFilter,
  LeaveList,
  LeaveResult,
  MyLeave,
  RequestLeaveForInput,
  RequestLeaveInput,
} from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toLeaveBalance, toLeaveList, toMyLeave } from "./mappers";

type Client = SupabaseClient<Database>;

const toResult = (row: { id?: string; days: number; warning?: "over_allowance" | null }): LeaveResult => ({
  id: row.id,
  days: row.days,
  warning: row.warning ?? null,
});

export const requestLeave = async (client: Client, input: RequestLeaveInput): Promise<LeaveResult> => {
  const raw = unwrap(
    await client.rpc("request_leave", {
      p_branch: input.branchId,
      p_type: input.leaveType,
      p_from: input.fromDate,
      p_to: input.toDate,
      p_part: input.part,
      p_reason: input.reason,
    })
  );
  return toResult(parseRpc("request_leave", requestLeaveResultSchema, raw));
};

export const requestLeaveFor = async (client: Client, input: RequestLeaveForInput): Promise<LeaveResult> => {
  const raw = unwrap(
    await client.rpc("request_leave_for", {
      p_user: input.userId,
      p_branch: input.branchId,
      p_type: input.leaveType,
      p_from: input.fromDate,
      p_to: input.toDate,
      p_part: input.part,
      p_reason: input.reason,
    })
  );
  return toResult(parseRpc("request_leave_for", requestLeaveResultSchema, raw));
};

export const cancelLeave = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("cancel_leave", { p_id: id }));
};

export const decideLeave = async (client: Client, input: DecideLeaveInput): Promise<LeaveResult> => {
  const raw = unwrap(
    await client.rpc("decide_leave", { p_id: input.id, p_approve: input.approve, p_note: input.note, p_type: input.leaveType })
  );
  return toResult(parseRpc("decide_leave", decideLeaveResultSchema, raw));
};

export const listLeaveRequests = async (client: Client, filter: LeaveFilter, page: number, pageSize: number): Promise<LeaveList> => {
  const raw = unwrap(
    await client.rpc("list_leave_requests", {
      p_branch: filter.branchId,
      p_status: filter.status,
      p_from: filter.from,
      p_to: filter.to,
      p_search: filter.search,
      p_page: page,
      p_page_size: pageSize,
    })
  );
  return toLeaveList(parseRpc("list_leave_requests", leaveListSchema, raw));
};

export const getMyLeave = async (client: Client, year?: number): Promise<MyLeave> =>
  toMyLeave(parseRpc("my_leave_requests", myLeaveSchema, unwrap(await client.rpc("my_leave_requests", { p_year: year }))));

export const getLeaveBalance = async (client: Client, userId: string, year: number): Promise<LeaveBalance> =>
  toLeaveBalance(parseRpc("leave_balance", leaveBalanceSchema, unwrap(await client.rpc("leave_balance", { p_user: userId, p_year: year }))));

export const saveLeaveAllowance = async (client: Client, userId: string, year: number, days: number): Promise<void> => {
  unwrap(await client.rpc("save_leave_allowance", { p_user: userId, p_year: year, p_days: days }));
};

export const getPendingLeaveCount = async (client: Client, branchId?: string): Promise<number> =>
  unwrap(await client.rpc("pending_leave_count", { p_branch: branchId }));
