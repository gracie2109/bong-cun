/** One file row of a stock receipt. */
export type ReceiptFileRow = {
  row: string;
  sku: string;
  qty: number | null;
  unit: string;
  cost: number | null;
  lotNo: string;
  expiry: string | null;
};
