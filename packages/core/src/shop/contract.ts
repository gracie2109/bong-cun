// Use-case contracts of the online shop money flow: placing an order and the staff steps that
// invoice and collect it. Same rules as pos/contract.ts: camelCase in, the database's `jsonb` out.
import { z } from "zod";
import { SHOP_ORDER_STATUSES } from "./shopOrder";

const uuid = z.string().uuid();

export const placeOrderInput = z
  .object({
    clientRef: uuid,
    deliveryMethod: z.enum(["delivery", "pickup"]),
    addressId: uuid.nullable(),
    receiver: z.object({ name: z.string().min(1), phone: z.string().min(1) }).nullable(),
    lines: z
      .array(z.object({ productId: uuid, unitId: uuid.nullable(), qty: z.number().int().positive() }))
      .min(1)
      .max(30),
    shippingFeeQuote: z.number().min(0).nullable(),
    note: z.string(),
  })
  .refine((order) => (order.deliveryMethod === "delivery" ? order.addressId !== null : order.receiver !== null), {
    message: "delivery needs an address and pickup needs a receiver",
  });

/** `place_shop_order` answers `{ id, code, total, replayed }`; `total` can arrive as a numeric string. */
export const placedOrderResultSchema = z.object({
  id: z.string(),
  code: z.string(),
  total: z.coerce.number(),
  replayed: z.boolean().nullish(),
});

export const payPickupInput = z.object({
  orderId: uuid,
  payments: z
    .array(z.object({ method: z.enum(["cash", "transfer", "card"]), amount: z.number().positive(), bankRef: z.string().nullish() }))
    .min(1),
});

/** The keys every staff step on an order (`confirm`, `pack`, `ship`, `deliver`, `pay_pickup`...) answers with. */
export const staffOrderResultSchema = z.object({
  id: z.string(),
  code: z.string(),
  branch_id: z.string(),
  status: z.enum(SHOP_ORDER_STATUSES),
  delivery_method: z.enum(["delivery", "pickup"]),
  payment_method: z.string(),
  subtotal: z.coerce.number(),
  shipping_fee: z.coerce.number().nullable(),
  total: z.coerce.number(),
  invoice: z.object({ id: z.string(), code: z.string(), status: z.string(), total: z.coerce.number() }).nullable(),
  lines: z.array(
    z.object({
      product_id: z.string(),
      name: z.string(),
      qty: z.coerce.number(),
      unit_price: z.coerce.number(),
      amount: z.coerce.number(),
    })
  ),
  events: z.array(z.object({ status: z.string() })),
});
