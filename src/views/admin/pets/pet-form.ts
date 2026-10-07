import type { PetInput, PetProfile, PetSex } from "@/repositories/pets";

/** The editable fields of a pet as the forms hold them (everything is a string or boolean). */
export type PetFormState = {
  speciesId: string;
  name: string;
  breed: string;
  sex: PetSex;
  neutered: boolean;
  birthDate: string;
  microchip: string;
  allergies: string;
  behaviorNotes: string;
};

export type PetFormErrors = { name: boolean; speciesId: boolean };

export const emptyPetForm = (): PetFormState => ({
  speciesId: "",
  name: "",
  breed: "",
  sex: "unknown",
  neutered: false,
  birthDate: "",
  microchip: "",
  allergies: "",
  behaviorNotes: "",
});

export const petToForm = (pet: PetProfile): PetFormState => ({
  speciesId: pet.speciesId,
  name: pet.name,
  breed: pet.breed ?? "",
  sex: pet.sex,
  neutered: pet.neutered,
  birthDate: pet.birthDate ?? "",
  microchip: pet.microchip ?? "",
  allergies: pet.allergies ?? "",
  behaviorNotes: pet.behaviorNotes ?? "",
});

export const formToPetInput = (form: PetFormState): PetInput => ({
  speciesId: form.speciesId,
  name: form.name.trim(),
  breed: form.breed.trim() || null,
  sex: form.sex,
  neutered: form.neutered,
  birthDate: form.birthDate || null,
  microchip: form.microchip.trim() || null,
  allergies: form.allergies.trim() || null,
  behaviorNotes: form.behaviorNotes.trim() || null,
});

export const petFormErrors = (form: PetFormState): PetFormErrors => ({
  name: form.name.trim().length === 0,
  speciesId: form.speciesId === "",
});

export const hasPetFormErrors = (errors: PetFormErrors): boolean =>
  errors.name || errors.speciesId;
