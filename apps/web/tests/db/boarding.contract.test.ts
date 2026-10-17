import {
  billableStaysSchema,
  checkedOutStaySchema,
  checkoutPreviewSchema,
  quoteSchema,
  savedStaySchema,
  stayPageSchema,
  stayRowSchema,
  typeAvailabilitySchema,
} from "@bongcun/core/boarding";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

const DAY = "(date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '%s') at time zone 'Asia/Ho_Chi_Minh'";
const at = (interval: string) => DAY.replace("%s", interval);

// An admin at a new branch, a customer with one pet, and one ready kennel of a priced type.
const setUpStay = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT6')");
  const admin = await db.scalar<string>("select tests.create_staff('contract-boarding@test.local', $1, 'cashier')", [branch]);
  await db.rows("update public.users set role = 'admin' where id = $1", [admin]);
  const customer = await db.scalar<string>("select tests.create_patient('0900000601', 'Contract Hotel Pet')");
  const pet = await db.scalar<string>("select tests.pet_of($1)", [customer]);
  const type = await db.scalar<string>(
    "insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Contract room', '{}', 'boarding', 1) returning id"
  );
  await db.rows("insert into public.kennel_type_prices (kennel_type_id, night_price) values ($1, 100000)", [type]);
  await db.rows("insert into public.kennels (branch_id, kennel_type_id, code) values ($1, $2, 'C1')", [branch, type]);
  const arrive = new Date(await db.scalar<string>(`select ${at("1 day 9 hours")}`)).toISOString();
  const leave = new Date(await db.scalar<string>(`select ${at("4 days 9 hours")}`)).toISOString();
  await db.signIn(admin);
  return { branch, customer, pet, type, arrive, leave };
};

const payloadOf = (s: Awaited<ReturnType<typeof setUpStay>>) => ({
  branch_id: s.branch,
  customer_id: s.customer,
  planned_in_at: s.arrive,
  planned_out_at: s.leave,
  pets: [{ pet_id: s.pet, kennel_type_id: s.type }],
});

describe("Boarding RPCs match the app's contract", () => {
  it("quote, availability, book, read back, list, check in, preview, check out and bill", async () => {
    await inRolledBackTransaction(async (db) => {
      const s = await setUpStay(db);

      const quote = quoteSchema.parse(await db.scalar("select public.boarding_quote($1, $2::jsonb, null)", [s.branch, JSON.stringify(payloadOf(s))]));
      expect(quote.items).toHaveLength(1);
      expect(quote.items?.[0]?.kennel_code).toBe("C1");

      const from = s.arrive.slice(0, 10);
      const availability = typeAvailabilitySchema.parse(
        await db.scalar("select public.boarding_availability($1, $2::date, $3::date)", [s.branch, from, s.leave.slice(0, 10)])
      );
      expect(availability?.some((row) => row.kennel_type_id === s.type && row.free === 1)).toBe(true);

      const saved = savedStaySchema.parse(await db.rpc("save_boarding_stay", payloadOf(s)));
      const stay = stayRowSchema.parse(await db.scalar("select public.get_boarding_stay($1)", [saved.id]));
      expect(stay.status).toBe("booked");
      expect(stay.pets).toHaveLength(1);

      const page = stayPageSchema.parse(await db.scalar("select public.list_boarding_stays($1)", [s.branch]));
      expect(page.total).toBe(1);

      const stayPet = stay.pets![0]!.id;
      const checkIn = [{ stay_pet_id: stayPet, weight_kg: 6, vaccine_checked: true, vaccine_note: "", belongings: "Bed" }];
      savedStaySchema.parse(await db.scalar("select public.check_in_boarding($1, $2::jsonb, null)", [saved.id, JSON.stringify(checkIn)]));
      expect(stayRowSchema.parse(await db.scalar("select public.get_boarding_stay($1)", [saved.id])).status).toBe("checked_in");

      const preview = checkoutPreviewSchema.parse(await db.scalar("select public.boarding_checkout_preview($1)", [saved.id]));
      expect(preview.items?.length).toBeGreaterThan(0);
      expect(preview.belongings?.[0]?.belongings).toBe("Bed");

      const out = checkedOutStaySchema.parse(await db.scalar("select public.check_out_boarding($1, $2::uuid[])", [saved.id, [stayPet]]));
      expect(out.total).toBeGreaterThan(0);

      const billable = billableStaysSchema.parse(await db.scalar("select public.billable_boarding_charges($1, $2)", [s.branch, s.customer]));
      expect(billable).toHaveLength(1);
      expect(billable?.[0]?.total).toBe(out.total);
    });
  });

  it("booking the only kennel twice raises a hint the app names", async () => {
    await inRolledBackTransaction(async (db) => {
      const s = await setUpStay(db);
      await db.rpc("save_boarding_stay", payloadOf(s));
      const error = await db.rpc("save_boarding_stay", payloadOf(s)).catch((e: unknown) => e);
      expect(["pet_busy", "no_kennel", "kennel_taken"]).toContain(toAppError(error)?.code);
    });
  });
});
