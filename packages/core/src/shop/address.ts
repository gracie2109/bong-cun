// Pure helpers for delivery addresses: no Vue, Pinia or network.
import type { Address, AddressInput, GhnLocation } from "@bongcun/core/shop";
import { emptyGhnLocation } from "@bongcun/core/shop";

/** What the address form edits: text fields plus the GHN place. */
export type AddressForm = {
  id?: string;
  receiverName: string;
  phone: string;
  street: string;
  location: GhnLocation;
  isDefault: boolean;
};

export const emptyAddressForm = (): AddressForm => ({
  receiverName: "",
  phone: "",
  street: "",
  location: emptyGhnLocation(),
  isDefault: false,
});

export const addressToForm = (address: Address): AddressForm => ({
  id: address.id,
  receiverName: address.receiverName,
  phone: address.phone,
  street: address.street,
  location: {
    provinceId: address.ghnProvinceId,
    provinceName: address.provinceName,
    districtId: address.ghnDistrictId,
    districtName: address.districtName,
    wardCode: address.ghnWardCode,
    wardName: address.wardName,
  },
  isDefault: address.isDefault,
});

/** One line for lists and the order: "12 Le Loi, Phuong 1, Quan 3, TP HCM". */
export const formatAddress = (
  address: Pick<Address, "street" | "wardName" | "districtName" | "provinceName">
): string => [address.street, address.wardName, address.districtName, address.provinceName].filter(Boolean).join(", ");

export type AddressErrors = Partial<Record<"receiverName" | "phone" | "street" | "location", true>>;

export const phoneDigits = (phone: string): string => phone.replace(/\D/g, "");

export const addressErrors = (form: AddressForm): AddressErrors => {
  const errors: AddressErrors = {};
  if (!form.receiverName.trim()) errors.receiverName = true;
  const digits = phoneDigits(form.phone).length;
  if (digits < 8 || digits > 15) errors.phone = true;
  if (!form.street.trim()) errors.street = true;
  const place = form.location;
  if (!place.provinceId || !place.districtId || !place.wardCode || !place.wardName) errors.location = true;
  return errors;
};

/** The form as the save call takes it; call only when `addressErrors` is empty. */
export const formToInput = (form: AddressForm): AddressInput => ({
  id: form.id,
  receiverName: form.receiverName.trim(),
  phone: form.phone.trim(),
  street: form.street.trim(),
  provinceName: form.location.provinceName,
  districtName: form.location.districtName,
  wardName: form.location.wardName,
  ghnProvinceId: form.location.provinceId as number,
  ghnDistrictId: form.location.districtId as number,
  ghnWardCode: form.location.wardCode as string,
  isDefault: form.isDefault,
});
