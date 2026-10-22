// The catalog id is part of every key, so a new sync of the cache refetches the lists.
export const locationKeys = {
  all: ["locations"] as const,
  catalog: () => [...locationKeys.all, "catalog"] as const,
  provinces: (catalogId: string) => [...locationKeys.all, catalogId, "provinces"] as const,
  communes: (catalogId: string, provinceCode: string) => [...locationKeys.all, catalogId, "communes", provinceCode] as const,
  unit: (catalogId: string, code: string) => [...locationKeys.all, catalogId, "unit", code] as const,
};
