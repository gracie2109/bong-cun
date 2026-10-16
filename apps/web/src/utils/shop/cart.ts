// Pure rules of the shop cart: no Vue, Pinia or network.
import type { CartLine, CartLineIssue, CartLineView } from "@bongcun/core/shop";

export const CART_STORAGE_KEY = "bc_cart_v1";
export const MAX_CART_LINES = 30;
export const MAX_LINE_QTY = 99;

/** Same product in the same unit is one line. */
export const lineKey = (line: Pick<CartLine, "productId" | "unitId">): string =>
  `${line.productId}:${line.unitId ?? ""}`;

export const clampQty = (qty: number): number => {
  const whole = Math.floor(Number(qty));
  return Number.isFinite(whole) ? Math.min(Math.max(whole, 1), MAX_LINE_QTY) : 1;
};

export type AddResult = "added" | "capped" | "cart_full";

/** Adds a line to a list; the same line again only raises its quantity (at most 99). */
export const addLine = (lines: readonly CartLine[], line: CartLine): { lines: CartLine[]; result: AddResult } => {
  const key = lineKey(line);
  const index = lines.findIndex((item) => lineKey(item) === key);
  if (index === -1) {
    if (lines.length >= MAX_CART_LINES) return { lines: [...lines], result: "cart_full" };
    return { lines: [...lines, { ...line, qty: clampQty(line.qty) }], result: "added" };
  }
  const wanted = lines[index].qty + clampQty(line.qty);
  const next = lines.map((item, i) => (i === index ? { ...item, qty: clampQty(wanted) } : item));
  return { lines: next, result: wanted > MAX_LINE_QTY ? "capped" : "added" };
};

/** Reads whatever was in localStorage: keeps valid, distinct lines and drops everything else. */
export const sanitizeLines = (raw: unknown): CartLine[] => {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const lines: CartLine[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const { productId, unitId, qty } = item as Record<string, unknown>;
    if (typeof productId !== "string" || !productId) continue;
    const line: CartLine = {
      productId,
      unitId: typeof unitId === "string" && unitId ? unitId : null,
      qty: clampQty(Number(qty)),
    };
    const key = lineKey(line);
    if (seen.has(key)) continue;
    seen.add(key);
    lines.push(line);
    if (lines.length >= MAX_CART_LINES) break;
  }
  return lines;
};

/** What stops one line from being ordered, or null when it can be. */
export const lineIssue = (line: CartLineView): CartLineIssue | null => {
  if (!line.isSellable || line.unitPrice === null) return { kind: "unavailable" };
  if (line.qty > line.available) return { kind: "over_stock", available: line.available };
  return null;
};

export const hasCartIssue = (lines: readonly CartLineView[]): boolean => lines.some((line) => lineIssue(line) !== null);

export const lineAmount = (line: CartLineView): number => (line.unitPrice ?? 0) * line.qty;

/** Sum of the lines that can be bought; lines that are off sale are not counted. */
export const cartSubtotal = (lines: readonly CartLineView[]): number =>
  lines.reduce((sum, line) => (line.isSellable ? sum + lineAmount(line) : sum), 0);

/** Grams of the whole cart. */
export const cartWeightG = (lines: readonly CartLineView[]): number =>
  lines.reduce((sum, line) => sum + line.weightG * line.qty, 0);

/** The cart holds an item that can only be picked up at the shop. */
export const hasInStoreOnly = (lines: readonly CartLineView[]): boolean =>
  lines.some((line) => line.shipPolicy === "in_store_only");
