import { canDeliver, MAX_DELIVERY_G, MAX_QUOTE_FEE, orderWeightG, placedOrderResultSchema } from "@bongcun/core/shop";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

// A shop with one product in stock and a signed-in customer who has an address.
const setUpShop = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT2')");
  await db.rows(
    `insert into public.shop_settings (online_branch_id, allow_cod, allow_pickup, flat_shipping_fee)
     values ($1, true, true, 30000)
     on conflict (id) do update set online_branch_id = excluded.online_branch_id, allow_cod = true, allow_pickup = true`,
    [branch]
  );
  const product = await db.scalar<string>("select tests.create_product('Contract kibble', 40000)");
  await db.scalar("select tests.add_lot($1, $2, 20, current_date + 90, 'CT-SHOP')", [branch, product]);
  const customer = await db.scalar<string>("select tests.create_user('contract-shopper@test.local', 'customer')");
  const address = await db.scalar<string>(
    `insert into public.customer_addresses
       (user_id, receiver_name, phone, street, province_name, district_name, ward_name,
        ghn_province_id, ghn_district_id, ghn_ward_code)
     values ($1, 'Contract Shopper', '0901234567', '1 Test St', 'Province', 'District', 'Ward', 1, 2, '3')
     returning id`,
    [customer]
  );
  return { product, customer, address };
};

describe("Checkout RPC matches the app's contract", () => {
  it("place_shop_order returns what the app reads, also when the same press is sent again", async () => {
    await inRolledBackTransaction(async (db) => {
      const { product, customer } = await setUpShop(db);
      await db.signIn(customer);
      const order = {
        client_ref: "11111111-1111-4111-8111-111111111111",
        delivery_method: "pickup",
        receiver: { name: "Contract Shopper", phone: "0901234567" },
        lines: [{ product_id: product, unit_id: null, qty: 2 }],
      };
      const first = placedOrderResultSchema.parse(await db.rpc("place_shop_order", order));
      expect(first.total).toBe(80_000);
      expect(first.replayed).toBe(false);
      const again = placedOrderResultSchema.parse(await db.rpc("place_shop_order", order));
      expect(again.id).toBe(first.id);
      expect(again.replayed).toBe(true);
    });
  });

  it("keeps the estimated shipping fee inside MAX_QUOTE_FEE, the cap the checkout screens use", async () => {
    await inRolledBackTransaction(async (db) => {
      const { product, customer, address } = await setUpShop(db);
      await db.signIn(customer);
      const placed = placedOrderResultSchema.parse(
        await db.rpc("place_shop_order", {
          client_ref: "22222222-2222-4222-8222-222222222222",
          delivery_method: "delivery",
          address_id: address,
          lines: [{ product_id: product, unit_id: null, qty: 1 }],
          shipping_fee_quote: MAX_QUOTE_FEE * 10,
        })
      );
      await db.signOut();
      const stored = await db.scalar<string>("select shipping_fee_quote from public.shop_orders where id = $1", [placed.id]);
      expect(Number(stored)).toBe(MAX_QUOTE_FEE);
    });
  });

  // The parcel is the goods plus packaging; both sides must agree on where "too heavy" starts.
  it.each([MAX_DELIVERY_G - 100, MAX_DELIVERY_G - 99])(
    "agrees with canDeliver for a delivery whose goods weigh %i g",
    async (goodsG) => {
      await inRolledBackTransaction(async (db) => {
        const { product, customer, address } = await setUpShop(db);
        await db.rows("update public.products set weight_g = $2 where id = $1", [product, goodsG]);
        await db.signIn(customer);
        const place = () =>
          db.rpc("place_shop_order", {
            client_ref: "33333333-3333-4333-8333-333333333333",
            delivery_method: "delivery",
            address_id: address,
            lines: [{ product_id: product, unit_id: null, qty: 1 }],
          });
        if (canDeliver(orderWeightG(goodsG))) {
          placedOrderResultSchema.parse(await place());
        } else {
          await expect(place()).rejects.toMatchObject({ code: "22023", hint: "too_heavy" });
        }
      });
    }
  );
});
