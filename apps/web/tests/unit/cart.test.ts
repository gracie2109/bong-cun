import { describe, expect, it } from "vitest";
import { addLine, clampQty, lineKey, MAX_CART_LINES, MAX_LINE_QTY, sanitizeLines } from "@bongcun/core/shop";

const line = (productId: string, qty = 1, unitId: string | null = null) => ({ productId, unitId, qty });

describe("cart", () => {
  it("treats the same product in another unit as another line", () => {
    expect(lineKey(line("a"))).not.toBe(lineKey(line("a", 1, "box")));
  });

  it("clamps quantities", () => {
    expect(clampQty(0)).toBe(1);
    expect(clampQty(1000)).toBe(MAX_LINE_QTY);
    expect(clampQty(Number.NaN)).toBe(1);
    expect(clampQty(2.9)).toBe(2);
  });

  it("raises the quantity of a repeated line and reports the cap", () => {
    const first = addLine([], line("a", 90));
    expect(first.result).toBe("added");
    const second = addLine(first.lines, line("a", 20));
    expect(second.lines).toEqual([line("a", MAX_LINE_QTY)]);
    expect(second.result).toBe("capped");
  });

  it("refuses new lines when the cart is full", () => {
    const full = Array.from({ length: MAX_CART_LINES }, (_, i) => line(`p${i}`));
    expect(addLine(full, line("new")).result).toBe("cart_full");
  });

  it("drops invalid and duplicate lines read from storage", () => {
    const raw = [line("a", 2), line("a", 5), { productId: "", qty: 1 }, null, "x", { productId: "b", qty: "3" }];
    expect(sanitizeLines(raw)).toEqual([line("a", 2), line("b", 3)]);
    expect(sanitizeLines("nope")).toEqual([]);
  });
});
