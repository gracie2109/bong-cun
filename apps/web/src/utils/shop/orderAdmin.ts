// Pure helpers for staff handling online orders: no Vue, Pinia or network.
import type { ShopOrderStatus } from "@bongcun/core/shop";
import type { AdminOrder, AdminOrderLine, OrderTab } from "@bongcun/core/shop";
import { formatAddress } from "./address";

/** A step staff can take on an order. */
export type OrderAction = "confirm" | "pack" | "ship" | "collect" | "deliver" | "return" | "cancel";

/** The buttons of an order, main action first. A pickup order is handed over and paid at the counter. */
export const orderActions = (order: Pick<AdminOrder, "status" | "deliveryMethod">): OrderAction[] => {
  const delivery = order.deliveryMethod === "delivery";
  switch (order.status) {
    case "pending":
      return ["confirm", "cancel"];
    case "confirmed":
      return ["pack", "cancel"];
    case "packed":
      return delivery ? ["ship", "cancel"] : ["collect", "cancel"];
    case "shipping":
      return ["deliver", "return"];
    default:
      return [];
  }
};

/** Lines that cannot be packed because the shelf has less than the order needs. */
export const shortLines = (lines: readonly AdminOrderLine[]): AdminOrderLine[] =>
  lines.filter((line) => line.trackStock && line.qty * line.unitFactor > line.available);

/** Only an order that has not been packed still holds a share of the stock, so only then can it be short. */
export const showStockCheck = (status: ShopOrderStatus): boolean => status === "pending" || status === "confirmed";

/** The tab an order sits in. */
export const tabOf = (status: ShopOrderStatus): OrderTab =>
  status === "cancelled" || status === "returned" ? "closed" : status;

/** The delivery address as one line, ready to paste into the GHN form. */
export const copyableAddress = (order: Pick<AdminOrder, "receiverName" | "receiverPhone" | "shipStreet" | "shipWardName" | "shipDistrictName" | "shipProvinceName">): string =>
  [
    `${order.receiverName} - ${order.receiverPhone}`,
    formatAddress({
      street: order.shipStreet ?? "",
      wardName: order.shipWardName ?? "",
      districtName: order.shipDistrictName ?? "",
      provinceName: order.shipProvinceName ?? "",
    }),
  ].join("\n");

/** Where a customer or staff member follows a GHN waybill. */
export const trackingUrl = (code: string): string => `https://donhang.ghn.vn/?order_code=${encodeURIComponent(code)}`;

/** The cash the courier collects: goods plus the confirmed shipping fee. */
export const codAmount = (order: Pick<AdminOrder, "subtotal" | "shippingFee" | "shippingFeeQuote">): number =>
  order.subtotal + (order.shippingFee ?? order.shippingFeeQuote);

/** A typed fee: digits only, null when nothing was typed. */
export const parseFee = (text: string): number | null => {
  const digits = text.replace(/\D/g, "");
  return digits ? Number(digits) : null;
};
