// Turns shop settings into what the settings form edits (text fields) and back.
import type { GhnLocation, ShopSettings } from "@bongcun/core/shop";
import { emptyGhnLocation } from "@bongcun/core/shop";

export type SettingsForm = {
  onlineBranchId: string;
  allowCod: boolean;
  allowPickup: boolean;
  codMax: string;
  defaultWeightG: string;
  flatShippingFee: string;
  freeShipFrom: string;
  /** Where GHN collects parcels. Names are not stored, the pickers fill them when a place is picked. */
  from: GhnLocation;
  fromAddressText: string;
  pickupAddress: string;
  pickupNote: string;
};

/** Digits only ("30.000" and "30000" both read 30000); null when nothing is typed. */
export const digitsOrNull = (text: string): number | null => {
  const digits = text.replace(/\D/g, "");
  return digits ? Number(digits) : null;
};

export const toForm = (settings: ShopSettings): SettingsForm => ({
  onlineBranchId: settings.onlineBranchId,
  allowCod: settings.allowCod,
  allowPickup: settings.allowPickup,
  codMax: String(settings.codMax),
  defaultWeightG: String(settings.defaultWeightG),
  flatShippingFee: String(settings.flatShippingFee),
  freeShipFrom: settings.freeShipFrom === null ? "" : String(settings.freeShipFrom),
  from: {
    ...emptyGhnLocation(),
    provinceId: settings.ghnFromProvinceId,
    districtId: settings.ghnFromDistrictId,
    wardCode: settings.ghnFromWardCode,
  },
  fromAddressText: settings.fromAddressText ?? "",
  pickupAddress: settings.pickupAddress ?? "",
  pickupNote: settings.pickupNote ?? "",
});

export const toSettings = (form: SettingsForm): ShopSettings => ({
  onlineBranchId: form.onlineBranchId,
  allowCod: form.allowCod,
  allowPickup: form.allowPickup,
  codMax: digitsOrNull(form.codMax) ?? 0,
  defaultWeightG: digitsOrNull(form.defaultWeightG) ?? 0,
  flatShippingFee: digitsOrNull(form.flatShippingFee) ?? 0,
  freeShipFrom: digitsOrNull(form.freeShipFrom),
  ghnFromProvinceId: form.from.provinceId,
  ghnFromDistrictId: form.from.districtId,
  ghnFromWardCode: form.from.wardCode,
  fromAddressText: form.fromAddressText.trim() || null,
  pickupAddress: form.pickupAddress.trim() || null,
  pickupNote: form.pickupNote.trim() || null,
});

/** i18n keys (under `shop.settings.errors`) of what is wrong, empty when the form can be saved. */
export const settingsErrors = (form: SettingsForm): string[] => {
  const errors: string[] = [];
  if (!form.onlineBranchId) errors.push("branch");
  if (!digitsOrNull(form.codMax)) errors.push("codMax");
  if (!digitsOrNull(form.defaultWeightG)) errors.push("defaultWeight");
  // A half-picked warehouse would make GHN reject every quote, so it is all or nothing.
  const from = form.from;
  const picked = [from.districtId, from.wardCode].filter(Boolean).length;
  if (picked === 1) errors.push("fromAddress");
  return errors;
};
