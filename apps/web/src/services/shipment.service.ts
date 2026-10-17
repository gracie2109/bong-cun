import { resolveApiUrl } from "@/composables/useApiUrl";

// GHN is called through our server routes (server/api/ghn), which hold the token, the ShopId and
// the service ids; the route picks light or heavy goods from the weight.

/** The two places and the parcel weight a GHN quote needs. */
export type ShippingPlaces = {
  fromDistrictId: number;
  fromWardCode: string;
  toDistrictId: number;
  toWardCode: string;
  /** Grams, packaging included. */
  weightG: number;
};

export type ShippingQuoteFailure = "too_heavy" | "unavailable";

/** A quote that could not be made; callers fall back to the flat fee. */
export class ShippingQuoteError extends Error {
  constructor(readonly reason: ShippingQuoteFailure, message?: string) {
    super(message ?? reason);
  }
}

type GhnResponse<T> = { code?: number; message?: string; data?: T };

const toBody = (input: ShippingPlaces & { insuranceValue?: number }) => ({
  fromDistrictId: input.fromDistrictId,
  fromWardCode: input.fromWardCode,
  toDistrictId: input.toDistrictId,
  toWardCode: input.toWardCode,
  weightG: Math.max(1, Math.round(input.weightG)),
  ...(input.insuranceValue === undefined ? {} : { insuranceValue: Math.max(0, Math.round(input.insuranceValue)) }),
});

const post = async <T>(path: string, body: object): Promise<GhnResponse<T>> => {
  try {
    return await $fetch<GhnResponse<T>>(resolveApiUrl(path), { method: "POST", body });
  } catch (error) {
    const status = (error as { statusCode?: number; status?: number }).statusCode ?? (error as { status?: number }).status;
    throw new ShippingQuoteError(status === 422 ? "too_heavy" : "unavailable");
  }
};

/** The shipping fee in VND for this parcel. Throws ShippingQuoteError when GHN cannot price it. */
export const quoteShippingFee = async (input: ShippingPlaces & { insuranceValue: number }): Promise<number> => {
  const response = await post<{ total?: number }>("/api/ghn/shipping-fee", toBody(input));
  const total = Number(response.data?.total);
  if (response.code !== 200 || !Number.isFinite(total) || total < 0) {
    throw new ShippingQuoteError("unavailable", response.message);
  }
  return total;
};

/** When GHN expects to deliver, or null when it cannot say. */
export const quoteLeadtime = async (input: ShippingPlaces): Promise<Date | null> => {
  const response = await post<{ leadtime?: number }>("/api/ghn/leadtime", toBody(input));
  const seconds = Number(response.data?.leadtime);
  return response.code === 200 && Number.isFinite(seconds) && seconds > 0 ? new Date(seconds * 1000) : null;
};
