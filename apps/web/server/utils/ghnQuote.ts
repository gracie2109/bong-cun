import { z } from "zod";
import { MAX_DELIVERY_G } from "../../src/utils/shop/shippingLimits";

// Rules for pricing a parcel with GHN, kept free of Nuxt so they can be tested alone.

/** GHN service types: 2 = light goods (under 20 kg), 5 = heavy goods. */
export const GHN_LIGHT_SERVICE_TYPE = 2;
export const GHN_HEAVY_SERVICE_TYPE = 5;
/** From this weight a parcel goes as heavy goods. */
export const HEAVY_FROM_G = 20_000;
/** GHN's insurance ceiling. */
export const MAX_INSURANCE_VALUE = 5_000_000;
/** Box size sent with every quote (cm); GHN prices light goods by the larger of weight and volume. */
const PARCEL_CM = { length: 30, width: 20, height: 15 } as const;

export type GhnServiceType = typeof GHN_LIGHT_SERVICE_TYPE | typeof GHN_HEAVY_SERVICE_TYPE;

/** The GHN service for a parcel of this weight, or null when it is too heavy to deliver. */
export const serviceTypeForWeight = (weightG: number): GhnServiceType | null => {
  if (weightG > MAX_DELIVERY_G) return null;
  return weightG >= HEAVY_FROM_G ? GHN_HEAVY_SERVICE_TYPE : GHN_LIGHT_SERVICE_TYPE;
};

const place = {
  fromDistrictId: z.number().int().positive(),
  fromWardCode: z.string().trim().min(1).max(20),
  toDistrictId: z.number().int().positive(),
  toWardCode: z.string().trim().min(1).max(20),
  weightG: z.number().int().min(1).max(1_000_000),
};

export const feeRequestSchema = z.object({
  ...place,
  insuranceValue: z.number().int().min(0).max(1_000_000_000).default(0),
});

export const leadtimeRequestSchema = z.object(place);

export type FeeRequest = z.infer<typeof feeRequestSchema>;
export type LeadtimeRequest = z.infer<typeof leadtimeRequestSchema>;

/** The body of GHN's /v2/shipping-order/fee. `serviceType` comes from serviceTypeForWeight. */
export const feeBody = (request: FeeRequest, serviceType: GhnServiceType) => ({
  service_type_id: serviceType,
  from_district_id: request.fromDistrictId,
  from_ward_code: request.fromWardCode,
  to_district_id: request.toDistrictId,
  to_ward_code: request.toWardCode,
  weight: request.weightG,
  ...PARCEL_CM,
  insurance_value: Math.min(request.insuranceValue, MAX_INSURANCE_VALUE),
  coupon: null,
});

/** The body of GHN's /v2/shipping-order/leadtime. `serviceId` is the shop's GHN service id. */
export const leadtimeBody = (request: LeadtimeRequest, serviceId: number) => ({
  from_district_id: request.fromDistrictId,
  from_ward_code: request.fromWardCode,
  to_district_id: request.toDistrictId,
  to_ward_code: request.toWardCode,
  service_id: serviceId,
});
