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
  /** The sending commune of the two-level address (a `location_units` code). */
  fromWardLocationCode: string | null;
  pickupAddress: string | null;
  pickupNote: string | null;
};

/** The staff view: the public fields plus the warehouse address as text. */
export type ShopSettings = ShopPublicSettings & {
  ghnFromProvinceId: number | null;
  fromAddressText: string | null;
  fromStreet: string | null;
};

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

// ------------------------------------------------------------------- cart

/** What the browser remembers of a cart line; everything else is read from the database. */
export type CartLine = {
  productId: string;
  /** The conversion unit sold (thùng, hộp...); null is the product's own unit. */
  unitId: string | null;
  qty: number;
};

/** Why a cart line cannot be bought, as shop_cart_lines reports it. */
export type CartLineReason = "not_found" | "inactive" | "unit_inactive";

/** A cart line with its live name, picture, shared shop price, weight and stock. */
export type CartLineView = CartLine & {
  groupId: string | null;
  name: string;
  /** "Gà / 85g": the variant's values; null for a product without attributes. */
  variant: string | null;
  imageUrl: string | null;
  unitName: string | null;
  /** Base units in one of this unit. */
  factor: number;
  unitPrice: number | null;
  /** Grams of one of this unit. */
  weightG: number;
  shipPolicy: ShipPolicy;
  /** How many of this unit can be bought now, at most 99. */
  available: number;
  isSellable: boolean;
  reason: CartLineReason | null;
};

/** What blocks a line from being ordered: it is off sale, or the quantity is above the stock. */
export type CartLineIssue = { kind: "unavailable" } | { kind: "over_stock"; available: number };

// --------------------------------------------------------------- addresses

/** `ghn_legacy`: province, district and ward by GHN ids. `vn_2025`: province and commune from the location cache. */
export type AddressLocationModel = "ghn_legacy" | "vn_2025";

/**
 * A delivery address of the signed-in shopper. Names print on the order. A legacy address carries
 * the GHN ids that price the delivery and a district; a two-level address carries location codes instead.
 */
export type Address = {
  id: string;
  receiverName: string;
  phone: string;
  street: string;
  provinceName: string;
  districtName: string | null;
  wardName: string;
  locationModel: AddressLocationModel;
  ghnProvinceId: number | null;
  ghnDistrictId: number | null;
  ghnWardCode: string | null;
  provinceLocationCode: string | null;
  wardLocationCode: string | null;
  isDefault: boolean;
};

/**
 * An address being saved; without `id` it is a new one. Give `wardLocationCode` for a two-level
 * address (the province follows from it), or the GHN fields for a legacy one.
 */
export type AddressInput = {
  id?: string;
  receiverName: string;
  phone: string;
  street: string;
  isDefault?: boolean;
  wardLocationCode?: string;
  provinceName?: string;
  districtName?: string;
  wardName?: string;
  ghnProvinceId?: number;
  ghnDistrictId?: number;
  ghnWardCode?: string;
};

/** Addresses an account may keep. */
export const MAX_ADDRESSES = 10;
