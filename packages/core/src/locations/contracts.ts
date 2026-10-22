// What the location_* RPCs answer with, checked with zod, and the camel-case shapes the app uses.
import { z } from "zod";
import type { LocationCatalog, LocationDetail, LocationPage, LocationSearchHit, LocationUnit } from "./types";

const refSchema = z.object({ code: z.string(), full_name: z.string() });

const unitRowSchema = z.object({
  code: z.string(),
  official_code: z.string().nullable(),
  name: z.string(),
  full_name: z.string(),
  unit_type: z.string(),
});

export const provincesSchema = z.array(unitRowSchema);
export const communePageSchema = z.object({ items: z.array(unitRowSchema), total: z.number() });

export const locationDetailSchema = unitRowSchema.extend({
  level: z.enum(["province", "commune"]),
  status: z.enum(["active", "retired"]),
  province: refSchema.nullable(),
});

export const searchPageSchema = z.object({
  items: z.array(z.object({ code: z.string(), full_name: z.string(), unit_type: z.string(), province: refSchema })),
  total: z.number(),
});

/** `location_catalog` answers null until the first sync. */
export const catalogSchema = z
  .object({
    id: z.string(),
    source: z.string(),
    effective_on: z.string(),
    synced_at: z.string(),
    record_counts: z.record(z.number()),
  })
  .nullable();

export const toLocationUnit = (row: z.infer<typeof unitRowSchema>): LocationUnit => ({
  code: row.code,
  officialCode: row.official_code,
  name: row.name,
  fullName: row.full_name,
  unitType: row.unit_type,
});

export const toLocationUnitPage = (page: z.infer<typeof communePageSchema>): LocationPage<LocationUnit> => ({
  items: page.items.map(toLocationUnit),
  total: page.total,
});

export const toLocationDetail = (row: z.infer<typeof locationDetailSchema>): LocationDetail => ({
  ...toLocationUnit(row),
  level: row.level,
  status: row.status,
  province: row.province && { code: row.province.code, fullName: row.province.full_name },
});

export const toLocationSearchPage = (page: z.infer<typeof searchPageSchema>): LocationPage<LocationSearchHit> => ({
  items: page.items.map((hit) => ({
    code: hit.code,
    fullName: hit.full_name,
    unitType: hit.unit_type,
    province: { code: hit.province.code, fullName: hit.province.full_name },
  })),
  total: page.total,
});

export const toLocationCatalog = (row: z.infer<typeof catalogSchema>): LocationCatalog | null =>
  row && {
    id: row.id,
    source: row.source,
    effectiveOn: row.effective_on,
    syncedAt: row.synced_at,
    recordCounts: row.record_counts,
  };
