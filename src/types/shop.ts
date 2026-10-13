// Shapes of the online shop (checkout, cart, orders) as the screens use them.

/** Everything the checkout needs from shop_settings; nothing in it is secret. */
export type ShopPublicSettings = {
  onlineBranchId: string;
  allowCod: boolean;
  allowPickup: boolean;
  codMax: number;
  defaultWeightG: number;
  flatShippingFee: number;
  /** Order value from which shipping is free; null when free shipping is off. */
  freeShipFrom: number | null;
  ghnFromDistrictId: number | null;
  ghnFromWardCode: string | null;
  pickupAddress: string | null;
  pickupNote: string | null;
};

/** The staff view: the public fields plus the warehouse address as text. */
export type ShopSettings = ShopPublicSettings & { ghnFromProvinceId: number | null; fromAddressText: string | null };

/** A place GHN knows: ids for fees, names for printing. */
export type GhnLocation = {
  provinceId: number | null;
  provinceName: string;
  districtId: number | null;
  districtName: string;
  wardCode: string | null;
  wardName: string;
};

export const emptyGhnLocation = (): GhnLocation => ({
  provinceId: null,
  provinceName: "",
  districtId: null,
  districtName: "",
  wardCode: null,
  wardName: "",
});

/** A product's shipping rule: in-store-only items cannot be delivered. */
export type ShipPolicy = "shippable" | "in_store_only";
