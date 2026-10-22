// Pure helpers for delivery addresses: no Vue, Pinia or network.
import type { Address, AddressInput } from "@bongcun/core/shop";
import type { LocationValue } from "@bongcun/core/locations";

/** The place names of an address saved before the 2025 reform, shown while the shopper picks again. */
export type LegacyPlace = { provinceName: string; districtName: string; wardName: string };

/**
 * What the address form edits: text fields plus the province and commune. `location` is null until
 * both are picked; `legacy` is set when an old-model address is being edited, which has to be re-picked.
 */
export type AddressForm = {
  id?: string;
  receiverName: string;
  phone: string;
  street: string;
  location: LocationValue | null;
  legacy: LegacyPlace | null;
  isDefault: boolean;
};

export const emptyAddressForm = (): AddressForm => ({
  receiverName: "",
  phone: "",
  street: "",
  location: null,
  legacy: null,
  isDefault: false,
});

export const addressToForm = (address: Address): AddressForm => {
  const base = { id: address.id, receiverName: address.receiverName, phone: address.phone, street: address.street, isDefault: address.isDefault };
  if (address.locationModel === "vn_2025" && address.provinceLocationCode && address.wardLocationCode) {
    return {
      ...base,
      location: {
        provinceCode: address.provinceLocationCode,
        provinceName: address.provinceName,
        wardCode: address.wardLocationCode,
        wardName: address.wardName,
      },
      legacy: null,
    };
  }
  return {
    ...base,
    location: null,
    legacy: { provinceName: address.provinceName, districtName: address.districtName ?? "", wardName: address.wardName },
  };
};

/** One line for lists and the order: "12 Le Loi, Phuong 1, Quan 3, TP HCM". */
export const formatAddress = (
  address: Pick<Address, "street" | "wardName" | "provinceName"> & { districtName?: string | null }
): string => [address.street, address.wardName, address.districtName, address.provinceName].filter(Boolean).join(", ");

export type AddressErrors = Partial<Record<"receiverName" | "phone" | "street" | "location", true>>;

export const phoneDigits = (phone: string): string => phone.replace(/\D/g, "");

export const addressErrors = (form: AddressForm): AddressErrors => {
  const errors: AddressErrors = {};
  if (!form.receiverName.trim()) errors.receiverName = true;
  const digits = phoneDigits(form.phone).length;
  if (digits < 8 || digits > 15) errors.phone = true;
  if (!form.street.trim()) errors.street = true;
  if (!form.location?.wardCode) errors.location = true;
  return errors;
};

/** The form as the save call takes it; call only when `addressErrors` is empty. */
export const formToInput = (form: AddressForm): AddressInput => ({
  id: form.id,
  receiverName: form.receiverName.trim(),
  phone: form.phone.trim(),
  street: form.street.trim(),
  wardLocationCode: form.location?.wardCode,
  isDefault: form.isDefault,
});
