export type LineType = "product" | "service" | "combo";
export type PaymentMethod = "cash" | "transfer" | "card";
export type InvoiceStatus = "paid" | "unpaid" | "cancelled";
/** Where an invoice was made: at the counter, or from an online order. */
export type InvoiceChannel = "pos" | "online";
export type ShiftStatus = "open" | "closed";

export const PAYMENT_METHODS: readonly PaymentMethod[] = ["cash", "transfer", "card"];

/** A discount above this share of the subtotal needs "pos: UPDATE" (checked again in the database). */
export const DISCOUNT_LIMIT = 0.1;
