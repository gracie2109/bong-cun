/** Whole percent saved against a higher reference price; 0 when there is no saving. */
export const salePercent = (price: number | null, compareAt: number | null | undefined): number => {
  if (price === null || !compareAt || compareAt <= price) return 0;
  return Math.round(((compareAt - price) / compareAt) * 100);
};
