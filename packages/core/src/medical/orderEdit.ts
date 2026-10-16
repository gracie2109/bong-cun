// Editing an in-patient order. The input says what a caller sends (camelCase, only the fields that
// changed); the Supabase adapter maps names. The medicine or service of an order never changes: a
// different one is a replacement (stop the old order and start a new one).
import { z } from "zod";

const hour = z.string().regex(/^([01][0-9]|2[0-3]):[0-5][0-9]$/);
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const updateOrderInput = z
  .object({
    dose: z.string().optional(),
    qtyPerDose: z.number().positive().optional(),
    times: z.array(hour).min(1).max(8).optional(),
    startOn: day.optional(),
    endOn: day.optional(),
    note: z.string().optional(),
    reason: z.string().optional(),
  })
  .refine((value) => !value.startOn || !value.endOn || value.endOn >= value.startOn, { message: "endOn before startOn" });
export type UpdateOrderInput = z.infer<typeof updateOrderInput>;

/** One line of the change log of an order, newest first. */
export type OrderChangeAction = "create" | "update" | "stop" | "replace";

export type OrderSnapshot = {
  dose: string | null;
  qtyPerDose: number;
  times: string[];
  startOn: string;
  endOn: string;
  note: string | null;
};

export type OrderChange = {
  id: string;
  action: OrderChangeAction;
  before: Partial<OrderSnapshot> | null;
  after: Partial<OrderSnapshot> | null;
  reason: string | null;
  changedByName: string | null;
  changedAt: string;
};

/** What `update_inpatient_order` answers: how many doses were added and removed. */
export const updateOrderResultSchema = z.object({
  id: z.string(),
  doses_added: z.number(),
  doses_removed: z.number(),
});
