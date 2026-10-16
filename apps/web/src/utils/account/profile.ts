import type { MyProfile, ProfileInput } from "@/types/account";
import { phoneDigits } from "@/utils/shop/address";

export type ProfileForm = ProfileInput;
export type ProfileErrors = Partial<Record<"fullName" | "phone" | "birthDate", true>>;

export const emptyProfileForm = (): ProfileForm => ({ fullName: "", phone: "", birthDate: "" });

export const profileToForm = (profile: MyProfile): ProfileForm => ({
  fullName: profile.fullName,
  phone: profile.phone,
  birthDate: profile.birthDate,
});

/** Name and phone are required (the customer record needs both); the birth date may be empty but not in the future. */
export const profileErrors = (form: ProfileForm, today = new Date()): ProfileErrors => {
  const errors: ProfileErrors = {};
  if (!form.fullName.trim()) errors.fullName = true;
  const digits = phoneDigits(form.phone).length;
  if (digits < 8 || digits > 15) errors.phone = true;
  if (form.birthDate) {
    const date = new Date(form.birthDate);
    if (Number.isNaN(date.getTime()) || date > today || date.getFullYear() < 1900) errors.birthDate = true;
  }
  return errors;
};

/** True when the form differs from the saved profile (to enable the save button). */
export const isProfileChanged = (form: ProfileForm, profile: MyProfile | undefined): boolean =>
  !profile ||
  form.fullName.trim() !== profile.fullName ||
  form.phone.trim() !== profile.phone ||
  form.birthDate !== profile.birthDate;
