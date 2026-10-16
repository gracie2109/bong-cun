// Editing, replacing, stopping and reading the history of an in-patient order.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@bongcun/supabase/db";
import type { OrderChange, OrderChangeAction, OrderInput, OrderSnapshot, UpdateOrderInput } from "@bongcun/core/medical";
import { updateOrderResultSchema } from "@bongcun/core/medical";
import { asRecord, str, strOrNull, unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

const ACTIONS: OrderChangeAction[] = ["create", "update", "stop", "replace"];

/** The `p` argument of save_inpatient_order and replace_inpatient_order. */
export const orderPayload = (input: OrderInput) => ({
  stay_pet_id: input.stayPetId,
  kind: input.kind,
  product_id: input.productId,
  service_id: input.serviceId,
  name: input.name,
  dose: input.dose,
  qty_per_dose: input.qtyPerDose,
  times: input.times,
  start_on: input.startOn,
  end_on: input.endOn,
  note: input.note,
});

/** Only the fields the caller sets are sent, so the database keeps the others. */
export const updateInpatientOrder = async (client: Client, id: string, input: UpdateOrderInput & { reason?: string }) => {
  const payload: { [key: string]: Json } = {};
  if (input.dose !== undefined) payload.dose = input.dose;
  if (input.qtyPerDose !== undefined) payload.qty_per_dose = input.qtyPerDose;
  if (input.times !== undefined) payload.times = input.times;
  if (input.startOn !== undefined) payload.start_on = input.startOn;
  if (input.endOn !== undefined) payload.end_on = input.endOn;
  if (input.note !== undefined) payload.note = input.note;
  if (input.reason?.trim()) payload.reason = input.reason.trim();
  const result = updateOrderResultSchema.parse(unwrap(await client.rpc("update_inpatient_order", { p_id: id, p: payload })));
  return { dosesAdded: result.doses_added, dosesRemoved: result.doses_removed };
};

/** Stops the order and starts a new one in a single step. */
export const replaceInpatientOrder = async (client: Client, id: string, input: OrderInput, reason?: string): Promise<void> => {
  const payload = { ...orderPayload(input), ...(reason?.trim() ? { reason: reason.trim() } : {}) };
  unwrap(await client.rpc("replace_inpatient_order", { p_id: id, p: payload }));
};

export const stopInpatientOrder = async (client: Client, id: string, reason?: string): Promise<void> => {
  unwrap(await client.rpc("stop_inpatient_order", { p_id: id, p_reason: reason?.trim() || undefined }));
};

const toSnapshot = (value: unknown): Partial<OrderSnapshot> | null => {
  if (!value || typeof value !== "object") return null;
  const row = asRecord(value);
  return {
    dose: strOrNull(row.dose),
    qtyPerDose: row.qty_per_dose == null ? undefined : Number(row.qty_per_dose),
    times: Array.isArray(row.times) ? row.times.map(str) : undefined,
    startOn: row.start_on == null ? undefined : str(row.start_on),
    endOn: row.end_on == null ? undefined : str(row.end_on),
    note: strOrNull(row.note),
  };
};

export const getInpatientOrderHistory = async (client: Client, orderId: string): Promise<OrderChange[]> => {
  const rows = unwrap(await client.rpc("inpatient_order_history", { p_order: orderId }));
  return (Array.isArray(rows) ? rows : []).map((raw) => {
    const row = asRecord(raw);
    return {
      id: str(row.id),
      action: ACTIONS.find((action) => action === row.action) ?? "update",
      before: toSnapshot(row.before),
      after: toSnapshot(row.after),
      reason: strOrNull(row.reason),
      changedByName: strOrNull(row.changed_by_name),
      changedAt: str(row.changed_at),
    };
  });
};
