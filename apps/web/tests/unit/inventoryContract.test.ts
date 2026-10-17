import { describe, expect, it } from "vitest";
import { stockAlertCountsSchema, stockDocumentInput } from "@bongcun/core/inventory";
import { toLinePayload, toMovement, toStockRow } from "@bongcun/supabase/inventory";

const uuid = "11111111-1111-4111-8111-111111111111";

describe("stock document input", () => {
  it("accepts receipt, write-off and count lines", () => {
    const parsed = stockDocumentInput.parse({
      branchId: uuid,
      docType: "receipt",
      lines: [
        { productId: uuid, lotNo: "A", expiryDate: null, qty: 2, unitCost: 1000 },
        { lotId: uuid, qty: 1 },
        { lotId: uuid, countedQty: 0 },
      ],
    });
    expect(parsed.lines).toHaveLength(3);
  });

  it("rejects an unknown document type", () => {
    expect(stockDocumentInput.safeParse({ branchId: uuid, docType: "gift", lines: [] }).success).toBe(false);
  });

  it("turns each line kind into the jsonb save_stock_document reads", () => {
    expect(toLinePayload({ productId: uuid, lotNo: "A", expiryDate: null, qty: 2, unitCost: 1000 })).toMatchObject({
      product_id: uuid,
      lot_no: "A",
      unit_id: null,
    });
    expect(toLinePayload({ lotId: uuid, countedQty: 4 })).toEqual({ lot_id: uuid, counted_qty: 4, note: null });
    expect(toLinePayload({ lotId: uuid, qty: 1 })).toEqual({ lot_id: uuid, qty: 1, note: null });
  });
});

describe("stock results", () => {
  it("fails when stock_alert_counts misses a key", () => {
    expect(stockAlertCountsSchema.safeParse({ low: 1, out: 0, expiring: 2 }).success).toBe(false);
    expect(stockAlertCountsSchema.safeParse({ low: 1, out: 0, expiring: 2, expired: 3 }).success).toBe(true);
  });

  it("maps a stock_summary row", () => {
    const row = toStockRow({
      product_id: uuid, name: "Kibble", sku: null, barcode: null, unit: "bag", is_active: true,
      on_hand: 5, sellable: 4, expired: 1, expiring: 0, next_expiry: null, stock_value: 5000, min_qty: null, total_count: 1,
    });
    expect(row).toMatchObject({ productId: uuid, onHand: 5, sellable: 4, minQty: null });
  });

  it("falls back to count for a movement reason it does not know", () => {
    const movement = toMovement({
      id: uuid, created_at: "2026-10-16", reason: "mystery", qty: 1, balance_after: 2, unit_cost: 3,
      stock_lots: null, stock_documents: { code: "NK-1" }, invoices: null, sales_returns: null,
    } as never);
    expect(movement).toMatchObject({ reason: "count", ref: "NK-1", lotNo: "" });
  });
});
