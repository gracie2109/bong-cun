// Online orders for staff: the list, one order, and the steps that move an order along.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { ShopOrderStatus } from "@/types/shopOrder";
import type {
  AdminOrder,
  AdminOrderPage,
  AdminOrderRow,
  OrderListFilter,
} from "@/types/shopOrderAdmin";
import { unwrap, type PageParams } from "../shared";
import type { PaymentMethod } from "../pos";

type Client = SupabaseClient<Database>;

type RowJson = {
  id: string;
  code: string;
  placed_at: string;
  receiver_name: string;
  receiver_phone: string;
  delivery_method: AdminOrderRow["deliveryMethod"];
  status: ShopOrderStatus;
  total: number | string;
  tracking_code: string | null;
  fee_confirmed: boolean;
  line_count: number | string;
};

type OrderJson = {
  id: string;
  code: string;
  branch_id: string;
  status: ShopOrderStatus;
  delivery_method: AdminOrder["deliveryMethod"];
  payment_method: AdminOrder["paymentMethod"];
  customer_id: string;
  receiver_name: string;
  receiver_phone: string;
  ship_street: string | null;
  ship_ward_name: string | null;
  ship_district_name: string | null;
  ship_province_name: string | null;
  ghn_district_id: number | null;
  ghn_ward_code: string | null;
  weight_g: number | string;
  subtotal: number | string;
  shipping_fee_quote: number | string;
  shipping_fee: number | string | null;
  total: number | string;
  customer_note: string | null;
  tracking_code: string | null;
  cancel_reason: string | null;
  placed_at: string;
  invoice: { id: string; code: string; status: "paid" | "unpaid" | "cancelled"; total: number | string } | null;
  lines: {
    product_id: string;
    unit_id: string | null;
    name: string;
    unit: string | null;
    image_url: string | null;
    qty: number | string;
    unit_factor: number | string;
    unit_price: number | string;
    amount: number | string;
    track_stock: boolean;
    available: number | string;
  }[];
  events: { status: ShopOrderStatus; note: string | null; actor_name: string | null; created_at: string }[];
};

const toRow = (row: RowJson): AdminOrderRow => ({
  id: row.id,
  code: row.code,
  placedAt: row.placed_at,
  receiverName: row.receiver_name,
  receiverPhone: row.receiver_phone,
  deliveryMethod: row.delivery_method,
  status: row.status,
  total: Number(row.total),
  trackingCode: row.tracking_code,
  feeConfirmed: row.fee_confirmed,
  lineCount: Number(row.line_count),
});

export const toAdminOrder = (row: OrderJson): AdminOrder => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  status: row.status,
  deliveryMethod: row.delivery_method,
  paymentMethod: row.payment_method,
  customerId: row.customer_id,
  receiverName: row.receiver_name,
  receiverPhone: row.receiver_phone,
  shipStreet: row.ship_street,
  shipWardName: row.ship_ward_name,
  shipDistrictName: row.ship_district_name,
  shipProvinceName: row.ship_province_name,
  ghnDistrictId: row.ghn_district_id,
  ghnWardCode: row.ghn_ward_code,
  weightG: Number(row.weight_g),
  subtotal: Number(row.subtotal),
  shippingFeeQuote: Number(row.shipping_fee_quote),
  shippingFee: row.shipping_fee === null ? null : Number(row.shipping_fee),
  total: Number(row.total),
  customerNote: row.customer_note,
  trackingCode: row.tracking_code,
  cancelReason: row.cancel_reason,
  placedAt: row.placed_at,
  invoice: row.invoice ? { ...row.invoice, total: Number(row.invoice.total) } : null,
  lines: row.lines.map((line) => ({
    productId: line.product_id,
    unitId: line.unit_id,
    name: line.name,
    unit: line.unit,
    imageUrl: line.image_url,
    qty: Number(line.qty),
    unitFactor: Number(line.unit_factor),
    unitPrice: Number(line.unit_price),
    amount: Number(line.amount),
    trackStock: line.track_stock,
    available: Number(line.available),
  })),
  events: row.events.map((event) => ({
    status: event.status,
    note: event.note,
    actorName: event.actor_name,
    createdAt: event.created_at,
  })),
});

export const listShopOrders = async (
  client: Client,
  page: PageParams,
  filter: OrderListFilter
): Promise<AdminOrderPage> => {
  const json = unwrap(
    await client.rpc("list_shop_orders", {
      p_status: filter.tab === "all" ? null : filter.tab,
      p_search: filter.search.trim() || null,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
    })
  ) as { rows: RowJson[]; total_count: number | string; counts: Record<string, number> };
  return { rows: json.rows.map(toRow), total: Number(json.total_count), counts: json.counts };
};

export const getShopOrder = async (client: Client, id: string): Promise<AdminOrder> =>
  toAdminOrder(unwrap(await client.rpc("get_shop_order", { p_id: id })) as OrderJson);

/** The steps of an order; each returns the order as it is afterwards. */
export type OrderStepCall =
  | { step: "confirm"; id: string; shippingFee: number | null }
  | { step: "pack"; id: string }
  | { step: "ship"; id: string; trackingCode: string }
  | { step: "deliver"; id: string }
  | { step: "return"; id: string; reason: string }
  | { step: "cancel"; id: string; reason: string }
  /** An in-store pickup order, collected and paid at the counter. */
  | { step: "pay"; id: string; payments: { method: PaymentMethod; amount: number; bankRef?: string | null }[] };

export const runOrderStep = async (client: Client, call: OrderStepCall): Promise<AdminOrder> => {
  const result = async () => {
    switch (call.step) {
      case "confirm":
        return client.rpc("confirm_shop_order", { p_id: call.id, p_shipping_fee: call.shippingFee });
      case "pack":
        return client.rpc("pack_shop_order", { p_id: call.id });
      case "ship":
        return client.rpc("ship_shop_order", { p_id: call.id, p_tracking_code: call.trackingCode });
      case "deliver":
        return client.rpc("deliver_shop_order", { p_id: call.id });
      case "return":
        return client.rpc("return_shop_order", { p_id: call.id, p_reason: call.reason });
      case "cancel":
        return client.rpc("cancel_shop_order", { p_id: call.id, p_reason: call.reason });
      case "pay":
        return client.rpc("pay_pickup_shop_order", {
          p_id: call.id,
          p_payments: call.payments.map((item) => ({ method: item.method, amount: item.amount, bank_ref: item.bankRef ?? null })),
        });
    }
  };
  return toAdminOrder(unwrap(await result()) as OrderJson);
};

/** Failure hints of the steps, for readable messages. */
export const STEP_ERROR_HINTS = [
  "order_not_found",
  "bad_status",
  "invalid_fee",
  "cod_limit",
  "tracking_required",
  "reason_required",
  "out_of_stock",
  "no_open_shift",
  "underpaid",
  "overpaid",
] as const;
export type StepErrorHint = (typeof STEP_ERROR_HINTS)[number];

export const stepErrorHint = (error: unknown): StepErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return STEP_ERROR_HINTS.find((item) => item === hint) ?? null;
};
