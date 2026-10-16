// Pure helpers for the shop's orders: no Vue, Pinia or network.
import type { Address, CartLine } from "@/types/shop";
import type { DeliveryMethod, ShopOrderDetail, ShopOrderEvent, ShopOrderStatus } from "@/types/shopOrder";

/** A customer may cancel until staff have packed the parcel. */
export const canCancelOrder = (status: ShopOrderStatus): boolean => status === "pending" || status === "confirmed";

/** An order that can still change; the page keeps refreshing while it is open. */
export const isOpenOrder = (status: ShopOrderStatus): boolean => status !== "completed" && status !== "cancelled" && status !== "returned";

/** The steps of an order that goes well, in order. Cancelled / returned orders stop the line. */
export const ORDER_STEPS: Record<DeliveryMethod, readonly ShopOrderStatus[]> = {
  delivery: ["pending", "confirmed", "packed", "shipping", "completed"],
  pickup: ["pending", "confirmed", "packed", "completed"],
};

export type StepState = "done" | "current" | "todo";

export type OrderStep = { status: ShopOrderStatus; state: StepState; at: string | null };

/** The progress line: reached steps carry the time they were reached. */
export const orderSteps = (method: DeliveryMethod, current: ShopOrderStatus, events: readonly ShopOrderEvent[]): OrderStep[] => {
  const steps = ORDER_STEPS[method];
  const reached = Math.max(steps.indexOf(current), -1);
  const at = new Map(events.map((event) => [event.status, event.createdAt]));
  return steps.map((status, index) => ({
    status,
    state: index < reached ? "done" : index === reached ? "current" : "todo",
    at: at.get(status) ?? null,
  }));
};

/** Tailwind classes of the status pill. */
export const STATUS_TONE: Record<ShopOrderStatus, string> = {
  pending: "bg-amber-100 text-amber-800",
  confirmed: "bg-sky-100 text-sky-800",
  packed: "bg-indigo-100 text-indigo-800",
  shipping: "bg-violet-100 text-violet-800",
  completed: "bg-emerald-100 text-emerald-800",
  cancelled: "bg-slate-200 text-slate-700",
  returned: "bg-rose-100 text-rose-800",
};

/** A fee staff confirmed that is above the estimate the shopper saw. */
export const feeWentUp = (order: Pick<ShopOrderDetail, "shippingFee" | "shippingFeeQuote">): boolean =>
  order.shippingFee !== null && order.shippingFee > order.shippingFeeQuote;

/** The fee that counts: the confirmed one, else the estimate. */
export const orderShippingFee = (order: Pick<ShopOrderDetail, "shippingFee" | "shippingFeeQuote">): number =>
  order.shippingFee ?? order.shippingFeeQuote;

export const newClientRef = (): string => crypto.randomUUID();

/** Pickup receiver as typed; empty parts are left for the database to fill from the account. */
export const pickupReceiver = (name: string, phone: string): { name: string; phone: string } => ({
  name: name.trim(),
  phone: phone.trim(),
});

export const isValidPhone = (phone: string): boolean => {
  const digits = phone.replace(/\D/g, "").length;
  return digits >= 8 && digits <= 15;
};

export type CheckoutErrors = { address?: true; receiverName?: true; receiverPhone?: true };

export type CheckoutDraft = {
  method: DeliveryMethod;
  address: Address | null;
  receiverName: string;
  receiverPhone: string;
};

/** What is missing before the order can be placed. */
export const checkoutErrors = (draft: CheckoutDraft): CheckoutErrors => {
  const errors: CheckoutErrors = {};
  if (draft.method === "delivery") {
    if (!draft.address) errors.address = true;
  } else {
    if (!draft.receiverName.trim()) errors.receiverName = true;
    if (!isValidPhone(draft.receiverPhone)) errors.receiverPhone = true;
  }
  return errors;
};

export const toCartInput = (lines: readonly CartLine[]): CartLine[] =>
  lines.map(({ productId, unitId, qty }) => ({ productId, unitId, qty }));

/** "15/10/2026", for dates in the shopper's language. */
export const formatDate = (date: Date | string): string => new Date(date).toLocaleDateString("vi-VN");

/** "15/10/2026 14:30". */
export const formatDateTime = (date: Date | string): string =>
  new Date(date).toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" });
