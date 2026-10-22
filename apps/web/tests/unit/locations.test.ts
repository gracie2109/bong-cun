import { describe, expect, it } from "vitest";
import {
  catalogSchema,
  communePageSchema,
  formatLocationLine,
  locationDetailSchema,
  searchPageSchema,
  toLocationCatalog,
  toLocationDetail,
  toLocationSearchPage,
  toLocationUnitPage,
} from "@bongcun/core/locations";
import { toAppError } from "@bongcun/supabase/shared";

describe("formatLocationLine", () => {
  it("joins street, commune and province", () => {
    expect(formatLocationLine("12 Lê Lợi", "Phường Bến Thành", "Thành phố Hồ Chí Minh")).toBe(
      "12 Lê Lợi, Phường Bến Thành, Thành phố Hồ Chí Minh"
    );
  });

  it("skips empty and blank parts", () => {
    expect(formatLocationLine(null, " Phường Bến Thành ", "")).toBe("Phường Bến Thành");
    expect(formatLocationLine(undefined, undefined, undefined)).toBe("");
  });
});

describe("location contract", () => {
  const row = { code: "vn_aaaaaaaaaaaaaaaaaaaa", official_code: "26740", name: "Bến Thành", full_name: "Phường Bến Thành", unit_type: "ward" };

  it("maps a page of communes", () => {
    const page = toLocationUnitPage(communePageSchema.parse({ items: [row], total: 1 }));
    expect(page).toEqual({
      items: [{ code: row.code, officialCode: "26740", name: "Bến Thành", fullName: "Phường Bến Thành", unitType: "ward" }],
      total: 1,
    });
  });

  it("maps a retired unit with its province", () => {
    const detail = toLocationDetail(
      locationDetailSchema.parse({ ...row, level: "commune", status: "retired", province: { code: "vn_bbbbbbbbbbbbbbbbbbbb", full_name: "Thành phố Hồ Chí Minh" } })
    );
    expect(detail).toMatchObject({ status: "retired", province: { fullName: "Thành phố Hồ Chí Minh" } });
  });

  it("maps search hits", () => {
    const page = toLocationSearchPage(
      searchPageSchema.parse({ items: [{ code: row.code, full_name: row.full_name, unit_type: "ward", province: { code: "p", full_name: "HCM" } }], total: 1 })
    );
    expect(page.items[0]).toMatchObject({ fullName: "Phường Bến Thành", province: { code: "p", fullName: "HCM" } });
  });

  it("reads a missing catalog as null", () => {
    expect(toLocationCatalog(catalogSchema.parse(null))).toBeNull();
    expect(
      toLocationCatalog(catalogSchema.parse({ id: "c", source: "s", effective_on: "2025-07-01", synced_at: "2026-11-01T00:00:00Z", record_counts: { provinces: 34 } }))
    ).toMatchObject({ effectiveOn: "2025-07-01", recordCounts: { provinces: 34 } });
  });

  it("fails on an unknown level", () => {
    expect(locationDetailSchema.safeParse({ ...row, level: "district", status: "active", province: null }).success).toBe(false);
  });

  it("turns the location hints into error codes", () => {
    expect(toAppError({ code: "P0002", hint: "location_not_found" })?.code).toBe("location_not_found");
    expect(toAppError({ code: "22023", hint: "location_search_too_short" })?.code).toBe("location_search_too_short");
  });
});
