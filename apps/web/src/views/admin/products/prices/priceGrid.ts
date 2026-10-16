import { parseAmount } from "@/views/admin/pos/format";

/** Key of one cell of the grid: a variant at a branch. */
export const cellKey = (productId: string, branchId: string) => `${productId}:${branchId}`;

/** The text shown for a saved branch price; empty means the general price applies. */
export const priceText = (price: number | undefined): string => (price === undefined ? "" : String(price));

/** The price a typed cell stands for; null when it is empty (no branch price). */
export const cellPrice = (text: string): number | null => (text.trim() ? parseAmount(text) : null);
