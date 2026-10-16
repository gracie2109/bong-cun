// The signed-in shopper's online orders: placing, listing, reading and cancelling.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type {
  PlaceOrderInput,
  PlacedOrder,
  ShopOrderDetail,
  ShopOrderPage,
  ShopOrderStatus,
  ShopOrderSummary,
} from "@bongcun/core/shop";
import { placedOrderResult } from "@bongcun/core/shop";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type SummaryJson = {
  id: string;
  code: string;
  status: ShopOrderStatus;
  delivery_method: ShopOrderSummary["deliveryMethod"];
  total: number | string;
  line_count: number | string;
  first_name: string | null;
  first_image: string | null;
  placed_at: string;
};

type DetailJson = {
  id: string;
  code: string;
  status: ShopOrderStatus;
  delivery_method: ShopOrderDetail["deliveryMethod"];
  payment_method: ShopOrderDetail["paymentMethod"];
  payment_status: ShopOrderDetail["paymentStatus"];
  receiver_name: string;
  receiver_phone: string;
  ship_street: string | null;
  ship_ward_name: string | null;
  ship_district_name: string | null;
  ship_province_name: string | null;
  weight_g: number | string;
  subtotal: number | string;
  shipping_fee_quote: number | string;
  shipping_fee: number | string | null;
  total: number | string;
  customer_note: string | null;
  carrier: string | null;
  tracking_code: string | null;
  cancel_reason: string | null;
  placed_at: string;
  lines: {
    product_id: string;
    unit_id: string | null;
    name: string;
    unit: string | null;
    image_url: string | null;
    qty: number | string;
    unit_price: number | string;
    amount: number | string;
  }[];
  events: { status: ShopOrderStatus; note: string | null; created_at: string }[];
};

const toSummary = (row: SummaryJson): ShopOrderSummary => ({
  id: row.id,
  code: row.code,
  status: row.status,
  deliveryMethod: row.delivery_method,
  total: Number(row.total),
  lineCount: Number(row.line_count),
  firstName: row.first_name,
  firstImage: row.first_image,
  placedAt: row.placed_at,
});

export const toOrderDetail = (row: DetailJson): ShopOrderDetail => ({
  id: row.id,
  code: row.code,
  status: row.status,
  deliveryMethod: row.delivery_method,
  paymentMethod: row.payment_method,
  paymentStatus: row.payment_status,
  receiverName: row.receiver_name,
  receiverPhone: row.receiver_phone,
  shipStreet: row.ship_street,
  shipWardName: row.ship_ward_name,
  shipDistrictName: row.ship_district_name,
  shipProvinceName: row.ship_province_name,
  weightG: Number(row.weight_g),
  subtotal: Number(row.subtotal),
  shippingFeeQuote: Number(row.shipping_fee_quote),
  shippingFee: row.shipping_fee === null ? null : Number(row.shipping_fee),
  total: Number(row.total),
  customerNote: row.customer_note,
  carrier: row.carrier,
  trackingCode: row.tracking_code,
  cancelReason: row.cancel_reason,
  placedAt: row.placed_at,
  lines: row.lines.map((line) => ({
    productId: line.product_id,
    unitId: line.unit_id,
    name: line.name,
    unit: line.unit,
    imageUrl: line.image_url,
    qty: Number(line.qty),
    unitPrice: Number(line.unit_price),
    amount: Number(line.amount),
  })),
  events: row.events.map((event) => ({ status: event.status, note: event.note, createdAt: event.created_at })),
});

export const placeShopOrder = async (client: Client, input: PlaceOrderInput): Promise<PlacedOrder> => {
  const json = unwrap(
    await client.rpc("place_shop_order", {
      p: {
        client_ref: input.clientRef,
        delivery_method: input.deliveryMethod,
        address_id: input.addressId,
        receiver: input.receiver,
        lines: input.lines.map((line) => ({ product_id: line.productId, unit_id: line.unitId, qty: line.qty })),
        shipping_fee_quote: input.shippingFeeQuote,
        note: input.note.trim() || null,
      },
    })
  );
  return parseRpc("place_shop_order", placedOrderResult, json);
};

export const listMyShopOrders = async (
  client: Client,
  params: { status: ShopOrderStatus | null; page: number; pageSize: number }
): Promise<ShopOrderPage> => {
  const json = unwrap(
    await client.rpc("my_shop_orders", {
      p_status: params.status,
      p_page: params.page,
      p_page_size: params.pageSize,
    })
  ) as { rows: SummaryJson[]; total_count: number | string };
  return { rows: json.rows.map(toSummary), totalCount: Number(json.total_count) };
};

export const getMyShopOrder = async (client: Client, code: string): Promise<ShopOrderDetail> =>
  toOrderDetail(unwrap(await client.rpc("my_shop_order", { p_code: code })) as DetailJson);

export const cancelMyShopOrder = async (client: Client, code: string, reason: string): Promise<ShopOrderDetail> =>
  toOrderDetail(
    unwrap(await client.rpc("cancel_my_shop_order", { p_code: code, p_reason: reason.trim() || null })) as DetailJson
  );

/** Failure hints raised by the order calls; the screens turn each into a message. */
export const ORDER_ERROR_HINTS = [
  "client_ref_required",
  "invalid_delivery",
  "delivery_disabled",
  "pickup_disabled",
  "address_not_found",
  "receiver_required",
  "invalid_phone",
  "cart_empty",
  "cart_too_big",
  "invalid_qty",
  "product_unavailable",
  "in_store_only",
  "out_of_stock",
  "too_heavy",
  "cod_limit",
  "order_not_found",
  "not_cancellable",
] as const;
export type OrderErrorHint = (typeof ORDER_ERROR_HINTS)[number];

export const orderErrorHint = (error: unknown): OrderErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return ORDER_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The product names an out_of_stock / in_store_only failure is about, when the database says. */
export const orderErrorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";
