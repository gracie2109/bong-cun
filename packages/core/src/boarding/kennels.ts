// Pet hotel (boarding): kennels, kennel types with their prices, and the rules of a branch.
export type KennelStatus = "ready" | "cleaning" | "maintenance";
export const KENNEL_STATUSES: readonly KennelStatus[] = ["ready", "cleaning", "maintenance"];

export type KennelPurpose = "boarding" | "medical" | "isolation";
export const KENNEL_PURPOSES: readonly KennelPurpose[] = ["boarding", "medical", "isolation"];

/** A price that replaces the shared one at one branch. */
export type BranchKennelPrice = {
  branchId: string;
  branchName: string;
  nightPrice: number;
  /** Each further pet in the kennel; null = the normal night price. */
  extraPetNightPrice: number | null;
};

export type KennelType = {
  id: string;
  name: string;
  description: string | null;
  photoUrl: string | null;
  speciesIds: string[];
  speciesNames: string[];
  /** Heaviest pet; null = no limit. */
  maxWeightKg: number | null;
  /** Pets of one stay that may share a kennel. */
  maxPets: number;
  purpose: KennelPurpose;
  isActive: boolean;
  isPublic: boolean;
  sortOrder: number;
  /** The price that applies at the branch the list was read for. */
  nightPrice: number | null;
  extraPetNightPrice: number | null;
  hasBranchPrice: boolean;
  sharedNightPrice: number | null;
  sharedExtraPetNightPrice: number | null;
  branchPrices: BranchKennelPrice[];
  /** Kennels of this type at that branch. */
  kennelCount: number;
};

export type KennelTypeInput = {
  name: string;
  description: string | null;
  photoUrl: string | null;
  speciesIds: string[];
  maxWeightKg: number | null;
  maxPets: number;
  isActive: boolean;
  isPublic: boolean;
  sortOrder: number;
  sharedNightPrice: number;
  sharedExtraPetNightPrice: number | null;
  branchPrices: Pick<BranchKennelPrice, "branchId" | "nightPrice" | "extraPetNightPrice">[];
};

export type Kennel = {
  id: string;
  branchId: string;
  kennelTypeId: string;
  kennelTypeName: string;
  code: string;
  name: string | null;
  status: KennelStatus;
  isActive: boolean;
  sortOrder: number;
};

export type KennelInput = {
  branchId: string;
  kennelTypeId: string;
  code: string;
  name: string | null;
  isActive: boolean;
  sortOrder: number;
};

/** Check-in and check-out rules of a branch. Times are "HH:mm". */
export type BoardingRules = {
  checkInFrom: string;
  checkOutBy: string;
  lateHalfUntil: string;
  maxNights: number;
  /** Nights charged for a pet dropped and collected on the same day (0.5 or 1). */
  dayStayNights: number;
};

export type KennelTypeFilter = { search?: string; activeOnly?: boolean };
export type KennelFilter = { search?: string; typeId?: string };
