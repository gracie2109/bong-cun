import {
  appointmentPageSchema,
  appointmentRowSchema,
  billableTicketsSchema,
  dayBoardSchema,
  savedAppointmentSchema,
  weekHoursSchema,
} from "@bongcun/core/spa";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

const TOMORROW_10 = "(((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1) + time '10:00') at time zone 'Asia/Ho_Chi_Minh'";

// An admin at a new branch, a customer with one pet, one fixed-price service and one spa table.
const setUpSpa = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT4')");
  const admin = await db.scalar<string>("select tests.create_staff('contract-spa@test.local', $1, 'cashier')", [branch]);
  await db.rows("update public.users set role = 'admin' where id = $1", [admin]);
  const customer = await db.scalar<string>("select tests.create_patient('0900000401', 'Contract Spa Pet')");
  const pet = await db.scalar<string>("select tests.pet_of($1)", [customer]);
  const service = await db.scalar<string>(
    "insert into public.pet_services (name, type, general_price, duration_minutes) values ('Contract wash', 'all', 150000, 30) returning id"
  );
  const resource = await db.scalar<string>("insert into public.spa_resources (branch_id, name) values ($1, 'Table 1') returning id", [branch]);
  const startAt = await db.scalar<string>(`select ${TOMORROW_10}`);
  await db.signIn(admin);
  return { branch, customer, pet, service, resource, startAt: new Date(startAt).toISOString() };
};

const bookingOf = (s: Awaited<ReturnType<typeof setUpSpa>>, extra: Record<string, unknown> = {}) => ({
  branch_id: s.branch,
  customer_id: s.customer,
  items: [{ pet_id: s.pet, type: "service", id: s.service, start_at: s.startAt, ...extra }],
});

describe("Spa RPCs match the app's contract", () => {
  it("book, read back, day board, week hours, check in and bill a ticket", async () => {
    await inRolledBackTransaction(async (db) => {
      const spa = await setUpSpa(db);
      const saved = savedAppointmentSchema.parse(await db.rpc("save_appointment", bookingOf(spa)));

      const appointment = appointmentRowSchema.parse(await db.scalar("select public.get_appointment($1)", [saved.id]));
      expect(appointment.status).toBe("booked");
      expect(appointment.items).toHaveLength(1);
      expect(appointment.items?.[0]?.est_price).toBe(150_000);

      const page = appointmentPageSchema.parse(await db.scalar("select public.list_appointments($1)", [spa.branch]));
      expect(page.total).toBe(1);

      const date = await db.scalar<string>(`select ((${TOMORROW_10}) at time zone 'Asia/Ho_Chi_Minh')::date::text`);
      const board = dayBoardSchema.parse(await db.scalar("select public.spa_day_board($1, $2::date)", [spa.branch, date]));
      expect(board.items).toHaveLength(1);

      expect(weekHoursSchema.parse(await db.scalar("select public.spa_week_hours($1)", [spa.branch]))).toHaveLength(7);

      await db.scalar("select public.check_in_appointment($1, $2::jsonb)", [saved.id, JSON.stringify([{ pet_id: spa.pet, weight_kg: 5 }])]);
      const ticket = appointment.items![0]!.id;
      await db.scalar("select public.set_appointment_item_status($1, 'in_progress')", [ticket]);
      await db.scalar("select public.set_appointment_item_status($1, 'done')", [ticket]);
      const billable = billableTicketsSchema.parse(
        await db.scalar("select public.billable_appointment_items($1, $2)", [spa.branch, spa.customer])
      );
      expect(billable).toHaveLength(1);
      expect(billable[0]?.unit_price).toBe(150_000);
    });
  });

  it("a second booking of the same table and time raises slot_resource", async () => {
    await inRolledBackTransaction(async (db) => {
      const spa = await setUpSpa(db);
      await db.rpc("save_appointment", bookingOf(spa, { resource_id: spa.resource }));
      const error = await db.rpc("save_appointment", bookingOf(spa, { resource_id: spa.resource })).catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("slot_resource");
    });
  });
});
