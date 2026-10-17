import { stockAlertCountsSchema } from "@bongcun/core/inventory";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

// An admin at a new branch with one stock-tracked product that has no lots yet.
const setUpStock = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT3')");
  const product = await db.scalar<string>("select tests.create_product('Contract stock', 20000)");
  const admin = await db.scalar<string>("select tests.create_cashier('contract-stock@test.local', $1)", [branch]);
  await db.rows("update public.users set role = 'admin' where id = $1", [admin]);
  await db.signIn(admin);
  return { branch, product };
};

const saveReceipt = (db: Session, branch: string, product: string, qty: number) =>
  db.rpc("save_stock_document", {
    branch_id: branch,
    doc_type: "receipt",
    lines: [{ product_id: product, lot_no: "CT-IN", expiry_date: null, qty, unit_cost: 1000 }],
  }) as Promise<string>;

describe("Stock RPCs match the app's contract", () => {
  it("a posted receipt shows in stock_summary and stock_alert_counts", async () => {
    await inRolledBackTransaction(async (db) => {
      const { branch, product } = await setUpStock(db);
      const id = await saveReceipt(db, branch, product, 12);
      await db.scalar("select public.post_stock_document($1)", [id]);

      const [row] = await db.rows<{ on_hand: string; sellable: string; total_count: string }>(
        "select * from public.stock_summary($1, null, 'all', 60, 20, 0)",
        [branch]
      );
      expect(Number(row?.on_hand)).toBe(12);
      expect(Number(row?.sellable)).toBe(12);
      expect(Number(row?.total_count)).toBe(1);

      const counts = stockAlertCountsSchema.parse(await db.scalar("select public.stock_alert_counts($1, 60)", [branch]));
      expect(counts.out).toBe(0);
      expect(counts.expired).toBe(0);
    });
  });

  it("posting a document twice raises not_draft", async () => {
    await inRolledBackTransaction(async (db) => {
      const { branch, product } = await setUpStock(db);
      const id = await saveReceipt(db, branch, product, 5);
      await db.scalar("select public.post_stock_document($1)", [id]);
      const error = await db.scalar("select public.post_stock_document($1)", [id]).catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("not_draft");
    });
  });

  it("a write-off larger than the lot raises lot_short", async () => {
    await inRolledBackTransaction(async (db) => {
      const { branch, product } = await setUpStock(db);
      await db.scalar("select public.post_stock_document($1)", [await saveReceipt(db, branch, product, 3)]);
      const lot = await db.scalar<string>("select id from public.stock_lots where branch_id = $1", [branch]);
      const writeoff = (await db.rpc("save_stock_document", {
        branch_id: branch,
        doc_type: "writeoff",
        lines: [{ lot_id: lot, qty: 10 }],
      })) as string;
      const error = await db.scalar("select public.post_stock_document($1)", [writeoff]).catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("lot_short");
    });
  });
});
