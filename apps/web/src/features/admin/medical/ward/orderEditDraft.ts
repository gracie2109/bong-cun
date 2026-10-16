import { todayKey } from "@/features/admin/schedule/format";
import type { UpdateOrderInput, WardOrder } from "@bongcun/core/medical";

/** The fields of an order a vet may edit; the medicine itself never changes (replace the order for that). */
export type OrderEditDraft = {
  dose: string;
  qtyPerDose: number;
  times: string[];
  startOn: string;
  endOn: string;
  note: string;
  reason: string;
};

export const editDraftFromOrder = (order: WardOrder): OrderEditDraft => ({
  dose: order.dose,
  qtyPerDose: order.qtyPerDose,
  times: [...order.times],
  startOn: order.startOn,
  endOn: order.endOn,
  note: order.note,
  reason: "",
});

/** An order that has not begun can still move its start date; once it has, doses may be recorded. */
export const canEditStart = (order: WardOrder): boolean => order.startOn > todayKey();

export const isEditDraftValid = (order: WardOrder, draft: OrderEditDraft): boolean =>
  draft.times.length > 0 &&
  draft.times.length <= 8 &&
  (order.kind === "care" || draft.qtyPerDose > 0) &&
  !!draft.startOn &&
  !!draft.endOn &&
  draft.endOn >= draft.startOn &&
  draft.endOn >= todayKey() &&
  Date.parse(draft.endOn) - Date.parse(draft.startOn) <= 30 * 24 * 60 * 60 * 1000;

const sameList = (left: string[], right: string[]) => left.length === right.length && left.every((value, index) => value === right[index]);

/** Only what changed, so an edit never overwrites a field it did not touch. */
export const toUpdateInput = (order: WardOrder, draft: OrderEditDraft): UpdateOrderInput => {
  const input: UpdateOrderInput = {};
  if (draft.dose.trim() !== order.dose) input.dose = draft.dose.trim();
  if (order.kind !== "care" && draft.qtyPerDose !== order.qtyPerDose) input.qtyPerDose = draft.qtyPerDose;
  if (!sameList([...draft.times].sort(), [...order.times].sort())) input.times = [...draft.times].sort();
  if (draft.startOn !== order.startOn) input.startOn = draft.startOn;
  if (draft.endOn !== order.endOn) input.endOn = draft.endOn;
  if (draft.note.trim() !== order.note) input.note = draft.note.trim();
  if (draft.reason.trim()) input.reason = draft.reason.trim();
  return input;
};

export const hasOrderChanges = (input: UpdateOrderInput): boolean => Object.keys(input).some((key) => key !== "reason");
