/** One file row as `import_pets` reads it. An empty value means "keep what is saved". */
export type PetImportRow = {
  row: string;
  owner_phone: string;
  owner_name: string;
  owner_email: string;
  owner_note: string;
  pet_name: string;
  species: string;
  breed: string;
  sex: "male" | "female" | "unknown" | "";
  neutered: boolean | null;
  birth_date: string | null;
  microchip: string;
  allergies: string;
  behavior_notes: string;
};
