// Medical records: service groups, diagnosis catalog, vaccine catalog and the rules of a branch.
export type ServiceCategory = "spa" | "medical" | "other";
export const SERVICE_CATEGORIES: readonly ServiceCategory[] = ["spa", "medical", "other"];

/** One diagnosis a vet can pick. Empty `speciesIds` = every species. */
export type DiagnosisTerm = {
  id: string;
  name: string;
  speciesIds: string[];
  speciesNames: string[];
  isContagious: boolean;
  isActive: boolean;
  sortOrder: number;
};

export type DiagnosisTermFilter = { search?: string; speciesId?: string; activeOnly?: boolean };

export type VaccineKind = "vaccine" | "deworm" | "other";
export const VACCINE_KINDS: readonly VaccineKind[] = ["vaccine", "deworm", "other"];

/** A vaccine, dewormer or other preventive shot with its simple protocol. */
export type VaccineType = {
  id: string;
  name: string;
  kind: VaccineKind;
  speciesIds: string[];
  speciesNames: string[];
  productId: string | null;
  productName: string | null;
  productUnit: string | null;
  /** Unexpired stock at the branch the list was read for; null when there is no product to count. */
  stockQty: number | null;
  /** Shots in the basic series. */
  seriesDoses: number;
  /** Days between the basic shots; null for a single shot. */
  seriesIntervalDays: number | null;
  /** Days from the last basic shot to the next one; null = no reminder. */
  boosterIntervalDays: number | null;
  minAgeWeeks: number | null;
  isActive: boolean;
  sortOrder: number;
};

export type VaccineTypeFilter = { search?: string; kind?: VaccineKind; speciesId?: string; activeOnly?: boolean };

