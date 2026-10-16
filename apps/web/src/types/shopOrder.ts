// Shapes of the online shop's orders as the screens use them.
import type { CartLine } from "./shop";

export type DeliveryMethod = "delivery" | "pickup";
export type PaymentMethod = "cod" | "pay_at_store";

export const SHOP_ORDER_STATUSES = [
  "pending",
  "confirmed",
  "packed",
  "shipping",
  "completed",
  "cancelled",
  "returned",
] as const;
export type ShopOrderStatus = (typeof SHOP_ORDER_STATUSES)[number];

/** What the checkout sends; the database reads prices, stock and the address itself. */
export type PlaceOrderInput = {
  /** One per press of "Đặt hàng" attempt; a retry with the same value returns the same order. */
  clientRef: string;
  deliveryMethod: DeliveryMethod;
  addressId: string | null;
  /** Pickup only: who collects the order. */
  receiver: { name: string; phone: string } | null;
  lines: readonly CartLine[];
  /** The fee shown to the shopper; only an estimate, staff confirm the real one. */
  shippingFeeQuote: number | null;
  note: string;
};

export type PlacedOrder = { id: string; code: string; total: number; replayed: boolean };

/** A row of "Đơn của tôi". */
export type ShopOrderSummary = {
  id: string;
  code: string;
  status: ShopOrderStatus;
  deliveryMethod: DeliveryMethod;
  total: number;
  lineCount: number;
  firstName: string | null;
  firstImage: string | null;
  placedAt: string;
};

export type ShopOrderPage = { rows: ShopOrderSummary[]; totalCount: number };

export type ShopOrderLine = {
  productId: string;
  unitId: string | null;
  name: string;
  unit: string | null;
  imageUrl: string | null;
  qty: number;
  unitPrice: number;
  amount: number;
};

export type ShopOrderEvent = { status: ShopOrderStatus; note: string | null; createdAt: string };

/** One order as its owner sees it. */
export type ShopOrderDetail = {
  id: string;
  code: string;
  status: ShopOrderStatus;
  deliveryMethod: DeliveryMethod;
  paymentMethod: PaymentMethod;
  paymentStatus: "paid" | "unpaid";
  receiverName: string;
  receiverPhone: string;
  shipStreet: string | null;
  shipWardName: string | null;
  shipDistrictName: string | null;
  shipProvinceName: string | null;
  weightG: number;
  subtotal: number;
  shippingFeeQuote: number;
  /** The fee staff confirmed; null while only the estimate exists. */
  shippingFee: number | null;
  total: number;
  customerNote: string | null;
  carrier: string | null;
  trackingCode: string | null;
  cancelReason: string | null;
  placedAt: string;
  lines: ShopOrderLine[];
  events: ShopOrderEvent[];
};
