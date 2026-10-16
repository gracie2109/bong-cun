// What the checkout RPC returns, as the app reads it (see packages/core/src/pos/contract.ts).
import { z } from "zod";

/** place_shop_order; PostgREST may send the total as a string. */
export const placedOrderResultSchema = z.object({
  id: z.string(),
  code: z.string(),
  total: z.coerce.number(),
  replayed: z.boolean().nullish(),
});
