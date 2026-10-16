// Pure shipping rules of the shop checkout: no Vue, Pinia or network.
import { MAX_DELIVERY_G, MAX_QUOTE_FEE } from "./shippingLimits";

export { MAX_DELIVERY_G, MAX_QUOTE_FEE };

/** Grams of packaging added to every order. */
export const PACKAGING_G = 100;
/** The confirmed fee may exceed the estimate by this much before staff are told to call the customer. */
export const FEE_WARN_DIFF = 10_000;

/** Weight of the parcel: the goods plus packaging. */
export const orderWeightG = (goodsG: number): number => Math.round(goodsG) + PACKAGING_G;

export const canDeliver = (parcelG: number): boolean => parcelG <= MAX_DELIVERY_G;

/** Where a shipping fee came from. */
export type FeeSource = "free" | "ghn" | "flat";

export type FeeInput = {
  subtotal: number;
  /** Order value from which shipping is free; null when free shipping is off. */
  freeShipFrom: number | null;
  /** The fee used when GHN cannot quote. */
  flatFee: number;
  /** GHN's quote, or null when none was made or it failed. */
  ghnFee: number | null;
};

export const isFreeShip = (subtotal: number, freeShipFrom: number | null): boolean =>
  freeShipFrom !== null && freeShipFrom > 0 && subtotal >= freeShipFrom;

/** The fee shown at checkout: free above the threshold, else GHN's quote, else the flat fee. */
export const resolveShippingFee = (input: FeeInput): { fee: number; source: FeeSource } => {
  if (isFreeShip(input.subtotal, input.freeShipFrom)) return { fee: 0, source: "free" };
  if (input.ghnFee !== null) return { fee: clampQuote(input.ghnFee), source: "ghn" };
  return { fee: clampQuote(input.flatFee), source: "flat" };
};

export const clampQuote = (fee: number): number => Math.min(Math.max(Math.round(fee), 0), MAX_QUOTE_FEE);

/** True when the confirmed fee is clearly above the estimate the customer saw. */
export const shouldWarnFeeChange = (quote: number, confirmed: number): boolean => confirmed - quote > FEE_WARN_DIFF;
