// Contract of the stock summary functions.
import { z } from "zod";

const uuid = z.string().uuid();

export const setMinStockInput = z.object({ branchId: uuid, productId: uuid, minQty: z.number().min(0).nullable() });

/** `stock_alert_counts` answers one count per alert filter. */
export const stockAlertCountsSchema = z.object({
  low: z.number(),
  out: z.number(),
  expiring: z.number(),
  expired: z.number(),
});
export type StockAlertCountsResult = z.infer<typeof stockAlertCountsSchema>;
