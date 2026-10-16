// RPC shape tests: every money function is called for real and its answer is parsed with the schema
// in @bongcun/core. If SQL renames or drops a key, the matching test fails here, in CI, not on a screen.
import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { saleResult, salesReturnResult, shiftSummaryResult } from "@bongcun/core/pos";
import { placedOrderResult, staffOrderResult } from "@bongcun/core/shop";
import { createBranch, createProduct, createStaff, createUser } from "./fixtures";
import { DATABASE_URL, inTransaction } from "./harness";

describe.skipIf(!DATABASE_URL)("counter sale, return and shift", () => {
  it("create_invoice, create_sales_return and the shift summary keep their shape", () =>
    inTransaction(async (tx) => {
      const branch = await createBranch(tx);
      const product = await createProduct(tx, branch, 50000, 20);
      const cashier = await createStaff(tx, branch, "admin", true); // returns need pos UPDATE, which the cashier role lacks
      await tx.as(cashier);

      const [{ create_invoice: rawSale }] = await tx.q<{ create_invoice: unknown }>(
        "select public.create_invoice($1::jsonb)",
        [JSON.stringify({
          branch_id: branch,
          client_ref: randomUUID(),
          lines: [{ type: "product", id: product, qty: 2 }],
          payments: [{ method: "cash", amount: 100000 }],
        })]
      );
      const sale = saleResult.parse(rawSale);
      expect(sale.total).toBe(100000);
      expect(sale.replayed).toBe(false);

      const [{ id: lineId }] = await tx.q<{ id: string }>("select id from public.invoice_lines where invoice_id = $1", [sale.id]);
      const [{ create_sales_return: rawReturn }] = await tx.q<{ create_sales_return: unknown }>(
        "select public.create_sales_return($1::jsonb)",
        [JSON.stringify({ invoice_id: sale.id, reason: "wrong size", refund_method: "cash", lines: [{ invoice_line_id: lineId, qty: 1 }] })]
      );
      expect(salesReturnResult.parse(rawReturn).refund_amount).toBe(50000);

      const [shift] = await tx.q<{ id: string }>("select id from public.cash_shifts where opened_by = $1", [cashier]);
      const [{ cash_shift_summary: summary }] = await tx.q<{ cash_shift_summary: unknown }>(
        "select public.cash_shift_summary($1)", [shift!.id]
      );
      const parsed = shiftSummaryResult.parse(summary);
      expect(parsed.invoice_count).toBe(1);
      expect(parsed.refund_cash).toBe(50000);

      const [{ close_cash_shift: closed }] = await tx.q<{ close_cash_shift: unknown }>(
        "select public.close_cash_shift($1, $2)", [shift!.id, parsed.expected_cash]
      );
      expect(shiftSummaryResult.parse(closed).counted_cash).toBe(parsed.expected_cash);
    }));

  it("open_cash_shift answers the new shift id", () =>
    inTransaction(async (tx) => {
      const branch = await createBranch(tx);
      const cashier = await createStaff(tx, branch, "cashier");
      await tx.as(cashier);
      const [{ open_cash_shift: id }] = await tx.q<{ open_cash_shift: string }>("select public.open_cash_shift($1, 0)", [branch]);
      expect(id).toMatch(/^[0-9a-f-]{36}$/);
    }));
});

describe.skipIf(!DATABASE_URL)("online order", () => {
  it("place_shop_order and every staff step keep their shape", () =>
    inTransaction(async (tx) => {
      const [{ online_branch_id: branch }] = await tx.q<{ online_branch_id: string }>("select online_branch_id from public.shop_settings");
      const product = await createProduct(tx, branch, 80000, 10);
      const buyer = await createUser(tx);
      const staff = await createStaff(tx, branch, "cashier", true);

      await tx.as(buyer);
      const [{ place_shop_order: raw }] = await tx.q<{ place_shop_order: unknown }>("select public.place_shop_order($1::jsonb)", [
        JSON.stringify({
          client_ref: randomUUID(),
          delivery_method: "pickup",
          receiver: { name: "An", phone: "0901234567" },
          lines: [{ product_id: product, unit_id: null, qty: 2 }],
        }),
      ]);
      const placed = placedOrderResult.parse(raw);
      expect(placed.total).toBe(160000);
      expect(placed.replayed).toBe(false);

      await tx.as(staff);
      for (const step of ["confirm_shop_order", "pack_shop_order"] as const) {
        const [row] = await tx.q<Record<string, unknown>>(`select public.${step}($1) as r`, [placed.id]);
        staffOrderResult.parse(row!.r);
      }
      const [{ r: paid }] = await tx.q<{ r: unknown }>("select public.pay_pickup_shop_order($1, $2::jsonb) as r", [
        placed.id,
        JSON.stringify([{ method: "cash", amount: 160000 }]),
      ]);
      const order = staffOrderResult.parse(paid);
      expect(order.status).toBe("completed");
      expect(order.invoice?.status).toBe("paid");
    }));
});
