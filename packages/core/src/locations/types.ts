// The administrative units Pawtiny caches from the Location Service (provinces and communes in force).

/** A unit as the pickers list it. `code` is the Location Service's opaque `vn_...` code. */
export type LocationUnit = {
  code: string;
  officialCode: string | null;
  name: string;
  fullName: string;
  unitType: string;
};

export type LocationRef = { code: string; fullName: string };

/** One unit read by code, retired ones included, so a saved address can still be shown. */
export type LocationDetail = LocationUnit & {
  level: "province" | "commune";
  status: "active" | "retired";
  province: LocationRef | null;
};

export type LocationSearchHit = { code: string; fullName: string; unitType: string; province: LocationRef };

export type LocationPage<T> = { items: T[]; total: number };

export type LocationCatalog = {
  id: string;
  source: string;
  effectiveOn: string;
  syncedAt: string;
  recordCounts: Record<string, number>;
};

/** What the address form holds: a province and a commune of it, names kept for display. */
export type LocationValue = {
  provinceCode: string;
  provinceName: string;
  wardCode: string;
  wardName: string;
};
