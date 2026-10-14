import type { MyPet, PetInput } from "@/types/account";

export type PetForm = PetInput;
export type PetErrors = Partial<Record<"name" | "speciesId" | "birthDate" | "weightKg", true>>;

export const emptyPetForm = (): PetForm => ({
  name: "",
  speciesId: "",
  breed: "",
  sex: "unknown",
  neutered: false,
  birthDate: "",
  allergies: "",
  behaviorNotes: "",
  weightKg: "",
});

export const petToForm = (pet: MyPet): PetForm => ({
  name: pet.name,
  speciesId: pet.speciesId,
  breed: pet.breed,
  sex: pet.sex,
  neutered: pet.neutered,
  birthDate: pet.birthDate,
  allergies: pet.allergies,
  behaviorNotes: pet.behaviorNotes,
  weightKg: pet.weightKg === null ? "" : String(pet.weightKg),
});

/** Name and species are required; birth date must not be in the future; weight is a positive number. */
export const petErrors = (form: PetForm, today = new Date()): PetErrors => {
  const errors: PetErrors = {};
  if (!form.name.trim()) errors.name = true;
  if (!form.speciesId) errors.speciesId = true;
  if (form.birthDate) {
    const date = new Date(form.birthDate);
    if (Number.isNaN(date.getTime()) || date > today || date.getFullYear() < 1990) errors.birthDate = true;
  }
  const weight = form.weightKg.trim();
  if (weight && !(Number(weight.replace(",", ".")) > 0 && Number(weight.replace(",", ".")) < 1000)) errors.weightKg = true;
  return errors;
};

/** The weight box accepts a comma as the decimal mark; the database wants a dot. */
export const normalizePetForm = (form: PetForm): PetForm => ({ ...form, weightKg: form.weightKg.trim().replace(",", ".") });

/** "2 years 3 months", "5 months" or "" when the birth date is unknown. Labels come from the caller. */
export const petAge = (birthDate: string, now = new Date()): { years: number; months: number } | null => {
  if (!birthDate) return null;
  const born = new Date(birthDate);
  if (Number.isNaN(born.getTime()) || born > now) return null;
  let months = (now.getFullYear() - born.getFullYear()) * 12 + (now.getMonth() - born.getMonth());
  if (now.getDate() < born.getDate()) months -= 1;
  months = Math.max(months, 0);
  return { years: Math.floor(months / 12), months: months % 12 };
};
