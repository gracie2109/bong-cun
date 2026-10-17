// Editing, replacing, stopping and reading the history of an in-patient order.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@bongcun/supabase/db";
import type { OrderChange, OrderInput, UpdateOrderInput } from "@bongcun/core/medical";
import { orderHistorySchema, updateOrderResultSchema } from "@bongcun/core/medical";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toOrderHistory } from "./mappers";

type Client = SupabaseClient<Database>;

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
  const result = parseRpc(
    "update_inpatient_order",
    updateOrderResultSchema,
    unwrap(await client.rpc("update_inpatient_order", { p_id: id, p: payload }))
  );
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

export const getInpatientOrderHistory = async (client: Client, orderId: string): Promise<OrderChange[]> =>
  toOrderHistory(parseRpc("inpatient_order_history", orderHistorySchema, unwrap(await client.rpc("inpatient_order_history", { p_order: orderId }))) ?? []);
