import { describe, expect, it } from "vitest";
import { appointmentInput, appointmentPageSchema, dayBoardSchema, weekHoursSchema } from "@bongcun/core/spa";
import { toAppointment, toDayBoard, toWeekHours } from "@bongcun/supabase/spa";

const row = {
  id: "a1", code: "LH-1", source: "counter", status: "booked", start_at: "2026-10-18T03:00:00Z", end_at: "2026-10-18T03:30:00Z",
  customer_id: "c1", customer_name: "An", customer_phone: null, note: null, checked_in_at: null,
  items: [{
    id: "t1", name: "Wash", item_type: "service", service_id: "s1", combo_id: null, status: "waiting", pet_id: "p1",
    pet_name: "Bông", start_at: "2026-10-18T03:00:00Z", end_at: "2026-10-18T03:30:00Z", est_price: 150000, billed: false,
  }],
};

describe("spa contract", () => {
  it("maps an appointment page and fills nullable text with empty strings", () => {
    const page = appointmentPageSchema.parse({ rows: [row], total: 1 });
    const [appointment] = page.rows!.map(toAppointment);
    expect(appointment).toMatchObject({ customerPhone: "", tickets: [{ itemId: "s1", unitPrice: null, billed: false }] });
  });

  it("fails when a ticket has an unknown status", () => {
    const bad = { rows: [{ ...row, items: [{ ...row.items[0], status: "lost" }] }], total: 1 };
    expect(appointmentPageSchema.safeParse(bad).success).toBe(false);
  });

  it("maps the day board and the week hours", () => {
    const board = toDayBoard(dayBoardSchema.parse({
      date: "2026-10-18", is_closed: false, open_time: "08:00", close_time: "20:00", staff: [], resources: [{ id: "r", name: "T1" }], items: [],
    }));
    expect(board.resources).toEqual([{ id: "r", name: "T1" }]);
    expect(toWeekHours(weekHoursSchema.parse([{ weekday: 1, open_time: "08:00", close_time: "20:00", is_closed: false }]))[0]).toEqual({
      weekday: 1, openTime: "08:00", closeTime: "20:00", isClosed: false,
    });
  });

  it("needs at least one ticket to book", () => {
    const uuid = "11111111-1111-4111-8111-111111111111";
    expect(appointmentInput.safeParse({ branchId: uuid, customerId: uuid, tickets: [] }).success).toBe(false);
  });
});
