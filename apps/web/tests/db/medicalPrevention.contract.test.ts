import {
  attachmentsSchema,
  checkedInVisitSchema,
  diagnosisTermPageSchema,
  givenVaccineSchema,
  medicalRulesRowSchema,
  petHealthFlagsSchema,
  reminderPageSchema,
  vaccineBookSchema,
  vaccineLotsSchema,
  vaccineTypePageSchema,
} from "@bongcun/core/medical";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpVisit } from "./medicalFixture";

describe("Medical vaccination, catalog and settings RPCs match the app's contract", () => {
  it("give a shot, read the e-book, reminders, catalogs, settings, flags and attachments", async () => {
    await inRolledBackTransaction(async (db) => {
      const m = await setUpVisit(db);
      const type = await db.scalar<string>(
        "insert into public.vaccine_types (name, kind, booster_interval_days) values ('Contract shot', 'vaccine', 365) returning id"
      );
      await db.rows("insert into public.diagnosis_terms (name) values ('Contract diagnosis')");

      const { id: visit } = checkedInVisitSchema.parse(
        await db.rpc("check_in_medical_visit", { branch_id: m.branch, customer_id: m.customer, pet_id: m.pet })
      );
      await db.scalar("select public.start_medical_visit($1)", [visit]);

      givenVaccineSchema.parse(await db.scalar("select public.give_vaccination($1, $2::jsonb)", [visit, JSON.stringify({ vaccine_type_id: type })]));
      const book = vaccineBookSchema.parse(await db.scalar("select public.pet_vaccinations($1)", [m.pet]));
      expect(book).toHaveLength(1);
      expect(book?.[0]?.doses).toHaveLength(1);

      vaccineLotsSchema.parse(await db.scalar("select public.vaccine_lots($1, $2)", [m.branch, type]));
      await db.scalar("select public.add_external_vaccination($1, $2::jsonb)", [
        m.pet,
        JSON.stringify({ vaccine_type_id: type, given_on: "2026-01-02", external_place: "Other clinic", dose_no: 2 }),
      ]);
      expect(vaccineBookSchema.parse(await db.scalar("select public.pet_vaccinations($1)", [m.pet]))?.[0]?.doses).toHaveLength(2);

      for (const scope of ["due", "overdue", "recheck"]) {
        reminderPageSchema.parse(await db.scalar("select public.medical_reminders($1, $2)", [m.branch, scope]));
      }

      const types = vaccineTypePageSchema.parse(await db.scalar("select public.list_vaccine_types(null, null, 1, 50, $1)", [m.branch]));
      expect(types.rows?.some((row) => row.id === type)).toBe(true);
      const terms = diagnosisTermPageSchema.parse(await db.scalar("select public.list_diagnosis_terms(null, null, 1, 50)"));
      expect(terms.rows?.some((row) => row.name === "Contract diagnosis")).toBe(true);
      expect(medicalRulesRowSchema.parse(await db.scalar("select public.medical_settings_get($1)", [m.branch])).remind_ahead_days).toBeGreaterThan(0);

      const flags = petHealthFlagsSchema.parse(await db.scalar("select public.pet_health_flags($1::uuid[])", [[m.pet]]));
      expect(flags?.[m.pet]).toBeDefined();

      await db.scalar("select public.add_medical_attachment($1, $2::jsonb)", [
        visit,
        JSON.stringify({ kind: "lab", title: "Blood test", file_path: `${m.pet}/${visit}/a.pdf`, mime_type: "application/pdf", size_bytes: 1024 }),
      ]);
      expect(attachmentsSchema.parse(await db.scalar("select public.list_medical_attachments($1)", [visit]))).toHaveLength(1);
    });
  });

  it("giving a shot from a type with a product but no batch raises no_lot", async () => {
    await inRolledBackTransaction(async (db) => {
      const m = await setUpVisit(db);
      const product = await db.scalar<string>("select tests.create_product('Contract vaccine', 100000)");
      const type = await db.scalar<string>("insert into public.vaccine_types (name, product_id) values ('Stocked shot', $1) returning id", [product]);
      const { id: visit } = checkedInVisitSchema.parse(
        await db.rpc("check_in_medical_visit", { branch_id: m.branch, customer_id: m.customer, pet_id: m.pet })
      );
      await db.scalar("select public.start_medical_visit($1)", [visit]);
      const error = await db
        .scalar("select public.give_vaccination($1, $2::jsonb)", [visit, JSON.stringify({ vaccine_type_id: type })])
        .catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("no_lot");
    });
  });
});
