// Online orders as staff see them (list, detail and the steps that move an order along).
import type { DeliveryMethod, PaymentMethod, ShopOrderStatus } from "./shopOrder";

/** The tabs of the order list: one status, the closed ones (cancelled and returned) or all. */
export type OrderTab = ShopOrderStatus | "closed" | "all";

export const ORDER_TABS: readonly OrderTab[] = ["pending", "confirmed", "packed", "shipping", "completed", "closed", "all"];

export type AdminOrderRow = {
  id: string;
  code: string;
  placedAt: string;
  receiverName: string;
  receiverPhone: string;
  deliveryMethod: DeliveryMethod;
  status: ShopOrderStatus;
  total: number;
  trackingCode: string | null;
  feeConfirmed: boolean;
  lineCount: number;
};

export type AdminOrderPage = {
  rows: AdminOrderRow[];
  total: number;
  /** Orders per status for the tabs; ignores the tab that is open. */
  counts: Partial<Record<ShopOrderStatus, number>>;
};

export type AdminOrderLine = {
  productId: string;
  unitId: string | null;
  name: string;
  unit: string | null;
  imageUrl: string | null;
  qty: number;
  unitFactor: number;
  unitPrice: number;
  amount: number;
  trackStock: boolean;
  /** Base units that can be sold, not counting what this order itself holds. */
  available: number;
};

export type AdminOrderEvent = { status: ShopOrderStatus; note: string | null; actorName: string | null; createdAt: string };

export type AdminOrderInvoice = { id: string; code: string; status: "paid" | "unpaid" | "cancelled"; total: number };

export type AdminOrder = {
  id: string;
  code: string;
  branchId: string;
  status: ShopOrderStatus;
  deliveryMethod: DeliveryMethod;
  paymentMethod: PaymentMethod;
  customerId: string;
  receiverName: string;
  receiverPhone: string;
  shipStreet: string | null;
  shipWardName: string | null;
  shipDistrictName: string | null;
  shipProvinceName: string | null;
  ghnDistrictId: number | null;
  ghnWardCode: string | null;
  weightG: number;
  subtotal: number;
  shippingFeeQuote: number;
  shippingFee: number | null;
  total: number;
  customerNote: string | null;
  trackingCode: string | null;
  cancelReason: string | null;
  placedAt: string;
  invoice: AdminOrderInvoice | null;
  lines: AdminOrderLine[];
  events: AdminOrderEvent[];
};

export type OrderListFilter = { tab: OrderTab; search: string };
