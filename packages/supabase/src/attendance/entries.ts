// Manager corrections of time entries, with the change history.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { entryChangeSchema } from "@bongcun/core/attendance";
import type { AddEntryInput, EditEntryInput, EntryChange } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const addTimeEntry = async (client: Client, input: AddEntryInput): Promise<string> =>
  unwrap(
    await client.rpc("add_time_entry", {
      p_branch: input.branchId,
      p_user: input.userId,
      p_in: input.checkInAt,
      p_out: input.checkOutAt,
      p_assignment: input.assignmentId,
      p_reason: input.reason,
    })
  );

export const editTimeEntry = async (client: Client, input: EditEntryInput): Promise<void> => {
  unwrap(
    await client.rpc("edit_time_entry", {
      p_id: input.id,
      p_in: input.checkInAt,
      p_out: input.checkOutAt,
      p_assignment: input.assignmentId,
      p_reason: input.reason,
    })
  );
};

export const deleteTimeEntry = async (client: Client, id: string, reason: string): Promise<void> => {
  unwrap(await client.rpc("delete_time_entry", { p_id: id, p_reason: reason }));
};

export const markEntryReviewed = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("mark_entry_reviewed", { p_id: id }));
};

export const getEntryHistory = async (client: Client, id: string): Promise<EntryChange[]> => {
  const raw = unwrap(await client.rpc("time_entry_history", { p_id: id }));
  return (raw ?? []).map((row) => {
    const r = parseRpc("time_entry_history", entryChangeSchema, row);
    return { id: r.id, action: r.action, before: r.before, after: r.after, reason: r.reason, changedByName: r.changed_by_name, changedAt: r.changed_at };
  });
};
