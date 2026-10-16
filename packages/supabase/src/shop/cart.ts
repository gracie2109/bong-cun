// The shop cart as the database sees it: live name, price, weight and stock for each line.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { CartLine, CartLineReason, CartLineView, ShipPolicy } from "@bongcun/core/shop";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type CartLineJson = {
  product_id: string;
  unit_id: string | null;
  qty: number;
  group_id: string | null;
  name: string;
  variant: string | null;
  image_url: string | null;
  unit_name: string | null;
  factor: number | string;
  unit_price: number | string | null;
  weight_g: number | string;
  ship_policy: ShipPolicy;
  available: number | string;
  is_sellable: boolean;
  reason: CartLineReason | null;
};

export const toCartLineView = (row: CartLineJson): CartLineView => ({
  productId: row.product_id,
  unitId: row.unit_id,
  qty: Number(row.qty),
  groupId: row.group_id,
  name: row.name,
  variant: row.variant,
  imageUrl: row.image_url,
  unitName: row.unit_name,
  factor: Number(row.factor),
  unitPrice: row.unit_price === null ? null : Number(row.unit_price),
  weightG: Number(row.weight_g),
  shipPolicy: row.ship_policy,
  available: Number(row.available),
  isSellable: row.is_sellable,
  reason: row.reason,
});

/** One view per line, in the order sent. Quantities come back as sent (kept between 1 and 99). */
export const fetchCartLines = async (client: Client, lines: readonly CartLine[]): Promise<CartLineView[]> => {
  if (lines.length === 0) return [];
  const rows = unwrap(
    await client.rpc("shop_cart_lines", {
      p_lines: lines.map((line) => ({ product_id: line.productId, unit_id: line.unitId, qty: line.qty })),
    })
  ) as CartLineJson[] | null;
  return (rows ?? []).map(toCartLineView);
};
