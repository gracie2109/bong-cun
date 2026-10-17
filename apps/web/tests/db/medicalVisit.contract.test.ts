import {
  billableVisitsSchema,
  checkedInVisitSchema,
  itemResultSchema,
  prescriptionSchema,
  queueSchema,
  signResultSchema,
  vetsSchema,
  visitDetailSchema,
  visitPageSchema,
} from "@bongcun/core/medical";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

// An admin at a new branch, a customer with one pet and one medical service.
const setUpVisit = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT7')");
  const admin = await db.scalar<string>("select tests.create_staff('contract-medical@test.local', $1, 'cashier')", [branch]);
  await db.rows("update public.users set role = 'admin' where id = $1", [admin]);
  const customer = await db.scalar<string>("select tests.create_patient('0900000701', 'Contract Vet Pet')");
  const pet = await db.scalar<string>("select tests.pet_of($1)", [customer]);
  const service = await db.scalar<string>(
    "insert into public.pet_services (name, type, general_price, duration_minutes, category) values ('Contract exam', 'all', 120000, 30, 'medical') returning id"
  );
  await db.signIn(admin);
  return { branch, customer, pet, service };
};

describe("Medical visit RPCs match the app's contract", () => {
  it("check in, queue, record, lines, sign, prescription, history and billing", async () => {
    await inRolledBackTransaction(async (db) => {
      const m = await setUpVisit(db);
      const checkedIn = checkedInVisitSchema.parse(
        await db.rpc("check_in_medical_visit", { branch_id: m.branch, customer_id: m.customer, pet_id: m.pet, reason: "cough" })
      );
      const id = checkedIn.id;

      const queue = queueSchema.parse(await db.scalar("select public.medical_queue($1)", [m.branch]));
      expect(queue.counts.waiting).toBe(1);
      expect(queue.rows?.[0]?.status).toBe("waiting");

      await db.scalar("select public.start_medical_visit($1)", [id]);
      const exam = itemResultSchema.parse(
        await db.scalar("select public.add_medical_item($1, $2::jsonb)", [id, JSON.stringify({ kind: "service", service_id: m.service, qty: 1 })])
      );
      itemResultSchema.parse(
        await db.scalar("select public.add_medical_item($1, $2::jsonb)", [
          id,
          JSON.stringify({ kind: "external", name: "Cough syrup", qty: 1, take_home: true, dose: "5 ml", frequency: "2x/day", days: 5 }),
        ])
      );
      itemResultSchema.parse(
        await db.scalar("select public.update_medical_item($1, $2::jsonb)", [exam.id, JSON.stringify({ instructions: "Fasting" })])
      );
      await db.scalar("select public.save_medical_record($1, $2::jsonb)", [
        id,
        JSON.stringify({ assessment: "Mild bronchitis", outcome: "home", diagnoses: [{ name: "Bronchitis", is_contagious: false }] }),
      ]);

      const detail = visitDetailSchema.parse(await db.scalar("select public.get_medical_visit($1)", [id]));
      expect(detail.items).toHaveLength(2);
      expect(detail.diagnoses?.[0]?.name).toBe("Bronchitis");
      expect(detail.pet?.id).toBe(m.pet);

      const signed = signResultSchema.parse(await db.scalar("select public.sign_medical_visit($1)", [id]));
      expect(signed.status).toBe("done");

      const prescription = prescriptionSchema.parse(await db.scalar("select public.medical_prescription($1)", [id]));
      expect(prescription.items?.some((item) => item.external)).toBe(true);

      const page = visitPageSchema.parse(await db.scalar("select public.list_medical_visits($1)", [m.branch]));
      expect(page.total).toBe(1);
      const history = visitPageSchema.parse(await db.scalar("select public.pet_medical_history($1)", [m.pet]));
      expect(history.total).toBe(1);
      vetsSchema.parse(await db.scalar("select public.medical_vets($1)", [m.branch]));

      const billable = billableVisitsSchema.parse(await db.scalar("select public.billable_medical_items($1, $2)", [m.branch, m.customer]));
      expect(billable).toHaveLength(1);
      expect(billable?.[0]?.total).toBe(120_000);
    });
  });

  it("a pet with an open visit raises pet_busy", async () => {
    await inRolledBackTransaction(async (db) => {
      const m = await setUpVisit(db);
      const visit = { branch_id: m.branch, customer_id: m.customer, pet_id: m.pet };
      await db.rpc("check_in_medical_visit", visit);
      const error = await db.rpc("check_in_medical_visit", visit).catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("pet_busy");
    });
  });
});
