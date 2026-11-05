import { myTimesheetSchema, timesheetGridSchema, timesheetListSchema } from "@bongcun/core/attendance";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Attendance report RPCs match the app's contract", () => {
  it("summary, monthly grid and my own timesheet", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const day = await db.scalar<string>("select (date_trunc('week', current_date)::date - 7)::text");
      const month = await db.scalar<string>("select date_trunc('month', $1::date)::date::text", [day]);
      const assignment = await db.scalar<string>(
        `insert into public.shift_assignments (branch_id, user_id, work_date, name, start_at, end_at)
         values ($1, $2, $3::date, 'Day', ($3::date + time '08:00') at time zone 'Asia/Ho_Chi_Minh', ($3::date + time '12:00') at time zone 'Asia/Ho_Chi_Minh')
         returning id`,
        [a.branch, a.staff, day]
      );
      await db.rows(
        `insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at, in_source, out_source)
         values ($1, $2, 'x', $3, ($4::date + time '08:00') at time zone 'Asia/Ho_Chi_Minh', ($4::date + time '12:00') at time zone 'Asia/Ho_Chi_Minh', 'manager', 'manager')`,
        [a.branch, a.staff, assignment, day]
      );

      await db.signIn(a.manager);
      const list = timesheetListSchema.parse(await db.scalar("select public.report_timesheet($1, $2::date, $2::date + 6, null, 20, 0)", [a.branch, day]));
      expect(list.total).toBeGreaterThanOrEqual(1);
      expect(list.rows.find((row) => row.user_id === a.staff)).toMatchObject({ shifts_scheduled: 1, shifts_worked: 1, worked_minutes: 240 });

      const grid = timesheetGridSchema.parse(await db.scalar("select public.report_timesheet_grid($1, $2::date)", [a.branch, month]));
      const cells = grid.staff.find((row) => row.user_id === a.staff)?.cells ?? [];
      expect(cells.find((cell) => cell.date === day)?.code).toBe("X");

      await db.signOut();
      await db.signIn(a.staff);
      const mine = myTimesheetSchema.parse(await db.scalar("select public.my_timesheet($1::date, $1::date + 6)", [day]));
      expect(mine.totals.worked_minutes).toBe(240);
    });
  });

  it("refuses staff without the attendance permission", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      await db.signIn(a.staff);
      const error = await db
        .rows("select public.report_timesheet($1, current_date - 7, current_date, null, 20, 0)", [a.branch])
        .then(() => null)
        .catch((caught: unknown) => caught);
      expect(toAppError(error)?.code).toBe("forbidden");
    });
  });
});
