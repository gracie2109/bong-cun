import {
  admittedSchema,
  checkedInVisitSchema,
  dischargedSchema,
  givenDoseSchema,
  inpatientKennelsSchema,
  medicalErrorHint,
  orderHistorySchema,
  wardSchema,
} from "@bongcun/core/medical";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpVisit } from "./medicalFixture";

describe("Medical in-patient RPCs match the app's contract", () => {
  it("admit, order, give a dose, log, read the ward and the order history, then discharge", async () => {
    await inRolledBackTransaction(async (db) => {
      const m = await setUpVisit(db);
      await db.signOut();
      const type = await db.scalar<string>(
        "insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Contract ward', '{}', 'medical', 1) returning id"
      );
      await db.rows("insert into public.kennel_type_prices (kennel_type_id, night_price) values ($1, 100000)", [type]);
      const kennel = await db.scalar<string>(
        "insert into public.kennels (branch_id, kennel_type_id, code) values ($1, $2, 'W1') returning id",
        [m.branch, type]
      );
      const today = await db.scalar<string>("select public.business_date()::text");
      await db.signIn(m.admin);

      const { id: visit } = checkedInVisitSchema.parse(
        await db.rpc("check_in_medical_visit", { branch_id: m.branch, customer_id: m.customer, pet_id: m.pet })
      );
      await db.scalar("select public.start_medical_visit($1)", [visit]);

      const kennels = inpatientKennelsSchema.parse(await db.scalar("select public.inpatient_kennels($1)", [m.branch]));
      expect(kennels).toEqual([expect.objectContaining({ id: kennel, purpose: "medical", free: true })]);

      const admitted = admittedSchema.parse(
        await db.scalar("select public.admit_inpatient($1, $2::jsonb)", [visit, JSON.stringify({ kennel_id: kennel, note: "drip" })])
      );

      await db.scalar("select public.save_inpatient_order($1::jsonb)", [
        JSON.stringify({ stay_pet_id: admitted.stay_pet_id, kind: "care", name: "Rest", dose: "", qty_per_dose: 1, times: ["00:00"], start_on: today, end_on: today, note: "" }),
      ]);
      const ward = wardSchema.parse(await db.scalar("select public.inpatient_ward($1)", [m.branch]));
      const row = ward.rows?.[0];
      expect(row).toMatchObject({ stay_pet_id: admitted.stay_pet_id, kennel_code: "W1", purpose: "medical" });
      expect(row?.orders).toHaveLength(1);
      expect(row?.doses).toHaveLength(1);

      givenDoseSchema.parse(await db.scalar("select public.give_inpatient_dose($1)", [row?.doses?.[0]?.id]));
      await db.scalar("select public.add_inpatient_log($1, $2::jsonb)", [admitted.stay_pet_id, JSON.stringify({ kind: "vitals", content: "T 38.5" })]);
      const after = wardSchema.parse(await db.scalar("select public.inpatient_ward($1)", [m.branch]));
      expect(after.rows?.[0]?.doses?.[0]?.given_at).toBeTruthy();
      expect(after.rows?.[0]?.last_vitals?.content).toBe("T 38.5");

      const history = orderHistorySchema.parse(await db.scalar("select public.inpatient_order_history($1)", [row?.orders?.[0]?.id]));
      expect(history?.[0]?.action).toBe("create");

      const discharged = dischargedSchema.parse(await db.scalar("select public.discharge_inpatient($1)", [admitted.stay_id]));
      expect(discharged.id).toBe(admitted.stay_id);
    });
  });

  it("admitting a pet that is already in the ward raises already_admitted", async () => {
    await inRolledBackTransaction(async (db) => {
      const m = await setUpVisit(db);
      await db.signOut();
      const type = await db.scalar<string>(
        "insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Contract ward', '{}', 'medical', 1) returning id"
      );
      await db.rows("insert into public.kennel_type_prices (kennel_type_id, night_price) values ($1, 100000)", [type]);
      const k1 = await db.scalar<string>("insert into public.kennels (branch_id, kennel_type_id, code) values ($1, $2, 'W1') returning id", [m.branch, type]);
      const k2 = await db.scalar<string>("insert into public.kennels (branch_id, kennel_type_id, code) values ($1, $2, 'W2') returning id", [m.branch, type]);
      await db.signIn(m.admin);
      const { id: visit } = checkedInVisitSchema.parse(
        await db.rpc("check_in_medical_visit", { branch_id: m.branch, customer_id: m.customer, pet_id: m.pet })
      );
      await db.scalar("select public.start_medical_visit($1)", [visit]);
      await db.scalar("select public.admit_inpatient($1, $2::jsonb)", [visit, JSON.stringify({ kennel_id: k1 })]);
      const error = await db.scalar("select public.admit_inpatient($1, $2::jsonb)", [visit, JSON.stringify({ kennel_id: k2 })]).catch((e: unknown) => e);
      expect(medicalErrorHint(error)).toBe("already_admitted");
    });
  });
});
