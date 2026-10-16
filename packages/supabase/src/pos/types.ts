export type LineType = "product" | "service" | "combo";
export { PAYMENT_METHODS, type PaymentMethod } from "@bongcun/core/pos";
export type InvoiceStatus = "paid" | "unpaid" | "cancelled";
/** Where an invoice was made: at the counter, or from an online order. */
export type InvoiceChannel = "pos" | "online";
export type ShiftStatus = "open" | "closed";


/** A discount above this share of the subtotal needs "pos: UPDATE" (checked again in the database). */
export const DISCOUNT_LIMIT = 0.1;
