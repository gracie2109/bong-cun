// The public pet hotel page (boarding_public_catalog).
export type BoardingWebKennelType = {
  id: string;
  name: string;
  description: string;
  photoUrl: string | null;
  maxWeightKg: number | null;
  maxPets: number;
  nightPrice: number;
  /** Price of each further pet sharing the kennel; null when the same as the first. */
  extraPetNightPrice: number | null;
  species: string[];
};

export type BoardingWebCatalog = {
  branch: { id: string; name: string; phone: string } | null;
  /** "HH:MM" */
  rules: { checkInFrom: string; checkOutBy: string; lateHalfUntil: string } | null;
  kennelTypes: BoardingWebKennelType[];
};
