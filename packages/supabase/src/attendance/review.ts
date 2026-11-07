// Reviewing shift requests: the manager's list, deciding, and the sidebar badge.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { decideRequestsResultSchema, shiftRequestListSchema } from "@bongcun/core/attendance";
import type { DecideRequestsInput, DecideRequestsResult, ShiftRequestFilter, ShiftRequestList } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toShiftRequestList } from "./registrationMappers";

type Client = SupabaseClient<Database>;

export const listShiftRequests = async (client: Client, filter: ShiftRequestFilter, page: number, pageSize: number): Promise<ShiftRequestList> =>
  toShiftRequestList(
    parseRpc(
      "list_shift_requests",
      shiftRequestListSchema,
      unwrap(
        await client.rpc("list_shift_requests", {
          p_branch: filter.branchId ?? undefined,
          p_status: filter.status,
          p_from: filter.from ?? undefined,
          p_to: filter.to ?? undefined,
          p_search: filter.search?.trim() || undefined,
          p_page: page,
          p_page_size: pageSize,
        })
      )
    )
  );

export const decideShiftRequests = async (client: Client, input: DecideRequestsInput): Promise<DecideRequestsResult> =>
  parseRpc(
    "decide_shift_requests",
    decideRequestsResultSchema,
    unwrap(await client.rpc("decide_shift_requests", { p_ids: input.ids, p_approve: input.approve, p_note: input.note ?? undefined, p_reason: input.reason ?? undefined }))
  );

export const getPendingShiftRequestCount = async (client: Client, branchId?: string): Promise<number> =>
  Number(unwrap(await client.rpc("pending_shift_request_count", { p_branch: branchId })) ?? 0);
