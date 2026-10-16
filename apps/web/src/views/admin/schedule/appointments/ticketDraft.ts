import type { TicketInput } from "@/repositories/spa";
import { toIso } from "../format";

/** Select value for "nobody / no table" (a Select cannot hold an empty string). */
export const NONE = "__none";

/** One ticket of the booking form: a pet, a service or combo ("service:<id>" / "combo:<id>"), and who does it where. */
export type TicketDraft = {
  key: string;
  petId: string;
  choice: string;
  time: string;
  staffId: string;
  resourceId: string;
};

let nextKey = 0;

export const newTicketDraft = (init: Partial<Omit<TicketDraft, "key">> = {}): TicketDraft => ({
  key: `ticket-${nextKey++}`,
  petId: "",
  choice: "",
  time: "",
  staffId: NONE,
  resourceId: NONE,
  ...init,
});

export const choiceOf = (type: "service" | "combo", id: string): string => `${type}:${id}`;

const parseChoice = (choice: string): { type: "service" | "combo"; id: string } | null => {
  const [type, id] = choice.split(":");
  return (type === "service" || type === "combo") && id ? { type, id } : null;
};

export const isComplete = (draft: TicketDraft): boolean => !!draft.petId && !!parseChoice(draft.choice) && !!draft.time;

/** The form row as the booking RPC takes it; null while it is incomplete. */
export const toTicketInput = (draft: TicketDraft, date: string): TicketInput | null => {
  const choice = parseChoice(draft.choice);
  if (!choice || !draft.petId || !draft.time) return null;
  return {
    petId: draft.petId,
    type: choice.type,
    id: choice.id,
    startAt: toIso(date, draft.time),
    staffId: draft.staffId === NONE ? null : draft.staffId,
    resourceId: draft.resourceId === NONE ? null : draft.resourceId,
  };
};
