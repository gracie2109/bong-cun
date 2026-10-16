/** Hints raised by the online order functions (`place_shop_order` and the staff steps), for readable messages. */
export const SHOP_ERROR_HINTS = [
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
  "unit_not_available",
  "no_price",
  "in_store_only",
  "out_of_stock",
  "too_heavy",
  "cod_limit",
  "invalid_fee",
  "order_not_found",
  "bad_status",
  "not_cancellable",
  "reason_required",
  "tracking_required",
  "no_open_shift",
  "underpaid",
  "overpaid",
] as const;
export type ShopErrorHint = (typeof SHOP_ERROR_HINTS)[number];

export const shopErrorHint = (error: unknown): ShopErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return SHOP_ERROR_HINTS.find((item) => item === hint) ?? null;
};
