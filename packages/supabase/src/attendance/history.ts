// The schedule history: the manager's log and the history of one shift or request.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { historyListSchema, historyOfSchema } from "@bongcun/core/attendance";
import type { HistoryFilter, HistoryList, HistoryRow } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toHistoryList, toHistoryRow } from "./historyMappers";

type Client = SupabaseClient<Database>;

export const listScheduleHistory = async (client: Client, filter: HistoryFilter, page: number, pageSize: number): Promise<HistoryList> =>
  toHistoryList(
    parseRpc(
      "schedule_history_list",
      historyListSchema,
      unwrap(
        await client.rpc("schedule_history_list", {
          p_branch: filter.branchId ?? undefined,
          p_from: filter.from ?? undefined,
          p_to: filter.to ?? undefined,
          p_user: filter.userId ?? undefined,
          p_entity: filter.entity ?? undefined,
          p_published_only: filter.publishedOnly,
          p_page: page,
          p_page_size: pageSize,
        })
      )
    )
  );

export const getScheduleHistoryOf = async (client: Client, entity: string, entityId: string): Promise<HistoryRow[]> =>
  parseRpc(
    "schedule_history_of",
    historyOfSchema,
    unwrap(await client.rpc("schedule_history_of", { p_entity: entity, p_entity_id: entityId }))
  ).map(toHistoryRow);
