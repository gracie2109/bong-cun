import { catalogSchema, communePageSchema, locationDetailSchema, provincesSchema, searchPageSchema } from "@bongcun/core/locations";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

// A made-up province with two communes, for this test only (the real cache is filled by the sync).
const addFixture = async (db: Session) => {
  // The real cache may already be filled by the sync; the fixture needs it empty (rolled back with the test).
  await db.rows("delete from public.location_provider_codes");
  await db.rows("delete from public.location_units");
  await db.rows("delete from public.location_catalogs");
  await db.rows(
    `insert into public.location_catalogs (id, source, effective_on, is_current, record_counts)
     values ('contract-catalog', 'test fixture', '2025-07-01', true, '{"provinces": 1}')`
  );
  await db.rows(
    `insert into public.location_units (code, level, unit_type, official_code, name, full_name, parent_code, status, effective_from, catalog_id) values
       ('vn_aaaaaaaaaaaaaaaaaaaa', 'province', 'province', '01', 'Tỉnh Thử', 'Tỉnh Thử', null, 'active', '2025-07-01', 'contract-catalog'),
       ('vn_bbbbbbbbbbbbbbbbbbbb', 'commune', 'ward', '0101', 'Bến Thử', 'Phường Bến Thử', 'vn_aaaaaaaaaaaaaaaaaaaa', 'active', '2025-07-01', 'contract-catalog'),
       ('vn_cccccccccccccccccccc', 'commune', 'ward', '0102', 'Đã Cũ', 'Phường Đã Cũ', 'vn_aaaaaaaaaaaaaaaaaaaa', 'retired', '2025-07-01', 'contract-catalog')`
  );
};

describe("Location cache RPCs match the app's contract", () => {
  it("answers what the app reads, also to a visitor who has not signed in", async () => {
    await inRolledBackTransaction(async (db) => {
      await addFixture(db);
      await db.rows("set local role anon");

      const provinces = provincesSchema.parse(await db.scalar("select public.location_provinces()"));
      expect(provinces.map((p) => p.code)).toEqual(["vn_aaaaaaaaaaaaaaaaaaaa"]);

      const communes = communePageSchema.parse(await db.scalar("select public.location_communes($1)", ["vn_aaaaaaaaaaaaaaaaaaaa"]));
      expect(communes.items.map((c) => c.full_name)).toEqual(["Phường Bến Thử"]);

      const found = searchPageSchema.parse(await db.scalar("select public.location_search($1)", ["ben thu"]));
      expect(found.items[0]?.province.full_name).toBe("Tỉnh Thử");

      const retired = locationDetailSchema.parse(await db.scalar("select public.location_unit($1)", ["vn_cccccccccccccccccccc"]));
      expect(retired.status).toBe("retired");

      expect(catalogSchema.parse(await db.scalar("select public.location_catalog()"))?.id).toBe("contract-catalog");
    });
  });
});
