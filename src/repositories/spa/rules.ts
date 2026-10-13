// Statuses, booking rules and the hints the spa RPCs attach to a refusal.
export type AppointmentStatus = "booked" | "checked_in" | "in_progress" | "done" | "paid" | "cancelled" | "no_show";
export type TicketStatus = "waiting" | "in_progress" | "done" | "cancelled";

export const APPOINTMENT_STATUSES: readonly AppointmentStatus[] = [
  "booked",
  "checked_in",
  "in_progress",
  "done",
  "paid",
  "cancelled",
  "no_show",
];

/** The tickets of a booked appointment can still be changed; nothing else can. */
export const isEditable = (status: AppointmentStatus): boolean => status === "booked";

/** Tickets can be started and finished from the moment the pet has checked in until it is paid. */
export const isServing = (status: AppointmentStatus): boolean =>
  status === "checked_in" || status === "in_progress" || status === "done";

/** Cancelling is possible until a ticket has started. */
export const isCancellable = (status: AppointmentStatus): boolean => status === "booked" || status === "checked_in";

/** Minutes between the start times offered when booking; the database requires the same step. */
export const SLOT_MINUTES = 15;

// Hints the RPCs attach to a refusal (see save_appointment).
export const SPA_ERROR_HINTS = [
  "slot_staff",
  "slot_resource",
  "closed",
  "outside_hours",
  "bad_time",
  "in_past",
  "not_editable",
  "no_customer",
  "no_pet",
  "bad_hours",
  "need_weight",
  "no_price",
  "not_due",
  "bad_status",
] as const;
export type SpaErrorHint = (typeof SPA_ERROR_HINTS)[number];

export const spaErrorHint = (error: unknown): SpaErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return SPA_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The service an error is about (the ticket that clashed), when the database names one. */
export const spaErrorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";

