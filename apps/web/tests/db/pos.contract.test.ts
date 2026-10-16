import { saleResultSchema, salesReturnResultSchema, shiftSummarySchema } from "@bongcun/core/pos";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";

// Runs the real POS functions and parses what they return with the schemas the app uses.
describe("POS RPC results match the app's contract", () => {
  it("create_invoice, create_sales_return and cash_shift_summary", async () => {
    await inRolledBackTransaction(async (db) => {
      const branch = await db.scalar<string>("select tests.create_branch('CT1')");
      const product = await db.scalar<string>("select tests.create_product('Contract pate', 25000)");
      const cashier = await db.scalar<string>("select tests.create_cashier('contract-cashier@test.local', $1)", [branch]);
      await db.scalar("select tests.add_lot($1, $2, 10, current_date + 90, 'CT-LOT')", [branch, product]);
      // Returns need an admin account type, as in supabase/tests/pos_invoice.test.sql.
      await db.rows("update public.users set role = 'admin' where id = $1", [cashier]);
      const shift = await db.scalar<string>("select id from public.cash_shifts where opened_by = $1", [cashier]);

      await db.signIn(cashier);
      const sale = saleResultSchema.parse(
        await db.rpc("create_invoice", {
          branch_id: branch,
          lines: [{ type: "product", id: product, qty: 3 }],
          payments: [{ method: "cash", amount: 80_000 }],
        })
      );
      expect(sale.total).toBe(75_000);
      expect(sale.change_amount).toBe(5_000);

      await db.signOut();
      const line = await db.scalar<string>("select id from public.invoice_lines where invoice_id = $1", [sale.id]);
      await db.signIn(cashier);
      const refund = salesReturnResultSchema.parse(
        await db.rpc("create_sales_return", {
          invoice_id: sale.id,
          reason: "contract test",
          refund_method: "cash",
          lines: [{ invoice_line_id: line, qty: 1 }],
        })
      );
      expect(refund.refund_amount).toBe(25_000);

      const summary = shiftSummarySchema.parse(await db.scalar("select public.cash_shift_summary($1)", [shift]));
      expect(summary.invoice_count).toBe(1);
      expect(summary.refund_cash).toBe(25_000);
    });
  });
});
