import { useLocalStorage } from "@vueuse/core";
import { defineStore } from "pinia";
import type { CartLine } from "@/types/shop";
import { addLine, CART_STORAGE_KEY, clampQty, lineKey, sanitizeLines, type AddResult } from "@/utils/shop/cart";

/**
 * The shop cart: only (product, unit, qty) per line, kept in localStorage so it survives a reload.
 * Names, pictures, prices and stock are read from the database by `useCartView`; a price kept in
 * the browser would never be trusted anyway.
 */
export const useCart = defineStore("cart", () => {
  // Read after mount so the server render and the first client render agree (an empty cart).
  const lines = useLocalStorage<CartLine[]>(CART_STORAGE_KEY, [], {
    initOnMounted: true,
    serializer: {
      read: (text) => {
        try {
          return sanitizeLines(JSON.parse(text));
        } catch {
          return [];
        }
      },
      write: (value) => JSON.stringify(value),
    },
  });

  /** Adds a line; the same product and unit again only raises the quantity (at most 99 per line). */
  const add = (productId: string, unitId: string | null, qty = 1): AddResult => {
    const next = addLine(lines.value, { productId, unitId, qty });
    lines.value = next.lines;
    return next.result;
  };

  const setQty = (key: string, qty: number) => {
    lines.value = lines.value.map((line) => (lineKey(line) === key ? { ...line, qty: clampQty(qty) } : line));
  };

  const remove = (key: string) => {
    lines.value = lines.value.filter((line) => lineKey(line) !== key);
  };

  /** Takes the given lines out (after they were ordered) and keeps the rest. */
  const removeMany = (keys: readonly string[]) => {
    const gone = new Set(keys);
    lines.value = lines.value.filter((line) => !gone.has(lineKey(line)));
  };

  const clear = () => {
    lines.value = [];
  };

  return { lines, add, setQty, remove, removeMany, clear };
});
