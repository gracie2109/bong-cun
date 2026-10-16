import { addDays, todayKey } from "@/views/admin/schedule/format";
import type { OrderInput, OrderKind } from "@bongcun/core/medical";

export const HOUR_PRESETS = ["06:00", "08:00", "12:00", "14:00", "18:00", "20:00", "22:00"];

export type OrderDraft = {
  kind: OrderKind;
  productId: string;
  serviceId: string;
  name: string;
  dose: string;
  qtyPerDose: number;
  times: string[];
  days: number;
  note: string;
};

export const emptyOrderDraft = (): OrderDraft => ({
  kind: "product",
  productId: "",
  serviceId: "",
  name: "",
  dose: "",
  qtyPerDose: 1,
  times: ["08:00", "20:00"],
  days: 3,
  note: "",
});

export const isOrderDraftComplete = (draft: OrderDraft, serviceNames: Map<string, string>): boolean => {
  if (draft.times.length === 0 || draft.qtyPerDose <= 0 || draft.days < 1 || draft.days > 30) return false;
  if (draft.kind === "product") return !!draft.productId;
  if (draft.kind === "service") return !!draft.serviceId && serviceNames.has(draft.serviceId);
  return !!draft.name.trim();
};

export const toOrderInput = (stayPetId: string, draft: OrderDraft): OrderInput => {
  const startOn = todayKey();
  return {
    stayPetId,
    kind: draft.kind,
    productId: draft.kind === "product" ? draft.productId : null,
    serviceId: draft.kind === "service" ? draft.serviceId : null,
    name: draft.kind === "care" ? draft.name.trim() : draft.name,
    dose: draft.dose.trim(),
    qtyPerDose: draft.kind === "care" ? 1 : draft.qtyPerDose,
    times: draft.times,
    startOn,
    endOn: addDays(startOn, draft.days - 1),
    note: draft.note.trim(),
  };
};
