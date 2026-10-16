import { staffOrderResultSchema } from "@bongcun/core/shop";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";

// A pickup order goes through the staff steps; each answers with the same order shape.
describe("Staff steps on an online order match the app's contract", () => {
  it("place, confirm, pack and pay at the counter", async () => {
    await inRolledBackTransaction(async (db) => {
      const branch = await db.scalar<string>("select tests.create_branch('CT3')");
      await db.rows(
        `insert into public.shop_settings (online_branch_id, allow_cod, allow_pickup, flat_shipping_fee)
         values ($1, true, true, 30000)
         on conflict (id) do update set online_branch_id = excluded.online_branch_id, allow_pickup = true`,
        [branch]
      );
      const product = await db.scalar<string>("select tests.create_product('Steps kibble', 80000)");
      await db.scalar("select tests.add_lot($1, $2, 10, null, 'ST-1')", [branch, product]);
      const buyer = await db.scalar<string>("select tests.create_user('steps-buyer@test.local')");
      const staff = await db.scalar<string>("select tests.create_cashier('steps-staff@test.local', $1)", [branch]);

      await db.signIn(buyer);
      const placed = (await db.rpc("place_shop_order", {
        client_ref: "44444444-4444-4444-8444-444444444444",
        delivery_method: "pickup",
        receiver: { name: "An", phone: "0901234567" },
        lines: [{ product_id: product, unit_id: null, qty: 2 }],
      })) as { id: string };

      await db.signIn(staff);
      for (const step of ["confirm_shop_order", "pack_shop_order"]) {
        staffOrderResultSchema.parse(await db.scalar(`select public.${step}($1)`, [placed.id]));
      }
      const paid = staffOrderResultSchema.parse(
        await db.scalar("select public.pay_pickup_shop_order($1, $2::jsonb)", [
          placed.id,
          JSON.stringify([{ method: "cash", amount: 160000 }]),
        ])
      );
      expect(paid.status).toBe("completed");
      expect(paid.invoice?.status).toBe("paid");
    });
  });
});
