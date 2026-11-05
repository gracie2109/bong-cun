import {
  attendanceErrorHint,
  clockInResultSchema,
  clockOutResultSchema,
  clockStatusSchema,
  entryChangeSchema,
  mySchedulePartSchema,
  todayBoardSchema,
} from "@bongcun/core/attendance";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Attendance clock RPCs match the app's contract", () => {
  it("clock in and out, the day board, corrections and the history", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      await db.rows(
        `insert into public.shift_assignments (branch_id, user_id, work_date, name, start_at, end_at)
         values ($1, $2, public.boarding_local_date(now()), 'Test', now() - interval '30 minutes', now() + interval '5 hours')`,
        [a.branch, a.staff]
      );

      await db.signIn(a.staff);
      const before = clockStatusSchema.parse(await db.scalar("select public.clock_status()"));
      expect(before.open_entry).toBeNull();
      expect(before.shifts).toHaveLength(1);

      const started = clockInResultSchema.parse(await db.scalar("select public.clock_in($1)", [a.branch]));
      expect(started.late_minutes).toBeGreaterThanOrEqual(30);
      expect(started.shift_name).toBe("Test");
      const open = clockStatusSchema.parse(await db.scalar("select public.clock_status()"));
      expect(open.open_entry?.id).toBe(started.entry_id);

      const mine = mySchedulePartSchema.parse(await db.scalar("select public.my_schedule(current_date - 1, current_date + 1)"));
      expect(mine.assignments[0]?.has_entry).toBe(true);
      expect(mine.entries[0]?.id).toBe(started.entry_id);

      const ended = clockOutResultSchema.parse(await db.scalar("select public.clock_out()"));
      expect(ended.entry_id).toBe(started.entry_id);

      await db.signOut();
      await db.signIn(a.manager);
      const board = todayBoardSchema.parse(await db.scalar("select public.attendance_today($1)", [a.branch]));
      expect(board.rows.find((row) => row.entry_id === started.entry_id)?.user_id).toBe(a.staff);
      expect(board.staff.map((row) => row.user_id)).toContain(a.staff);

      await db.rows("select public.edit_time_entry($1, now() - interval '3 hours', now() - interval '1 hour', null, 'Forgot to tap')", [started.entry_id]);
      const history = await db.rows<{ time_entry_history: unknown }>("select public.time_entry_history($1)", [started.entry_id]);
      const actions = history.map((row) => entryChangeSchema.parse(row.time_entry_history).action);
      expect(actions).toContain("update");
      await db.rows("select public.mark_entry_reviewed($1)", [started.entry_id]);
    });
  });

  it("every refusal carries a hint the app maps to a code", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const fail = async (sql: string, params: unknown[]) => {
        await db.rows("savepoint attempt");
        try {
          await db.rows(sql, params);
        } catch (error) {
          await db.rows("rollback to savepoint attempt");
          return error;
        }
        throw new Error("expected the call to fail");
      };

      await db.signIn(a.staff);
      const notIn = await fail("select public.clock_out()", []);
      expect(attendanceErrorHint(notIn)).toBe("not_in");
      expect(toAppError(notIn)?.code).toBe("not_in");

      const noShift = await fail("select public.clock_in($1, null, false)", [a.branch]);
      expect(toAppError(noShift)?.code).toBe("confirm_unscheduled");

      await db.rows("select public.clock_in($1, null, true)", [a.branch]);
      const twice = await fail("select public.clock_in($1, null, true)", [a.branch]);
      expect(toAppError(twice)?.code).toBe("already_in");

      const forbidden = await fail("select public.attendance_today($1)", [a.branch]);
      expect(toAppError(forbidden)?.code).toBe("forbidden");
    });
  });
});
