import {
  attendanceErrorHint,
  myShiftRequestsSchema,
  registrationBoardSchema,
  registrationRulesSchema,
  submitResultSchema,
} from "@bongcun/core/attendance";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";
import { setUpAttendance } from "./attendanceFixture";

const fail = async (db: Session, sql: string, params: unknown[]) => {
  await db.rows("savepoint attempt");
  try {
    await db.rows(sql, params);
  } catch (error) {
    await db.rows("rollback to savepoint attempt");
    return error;
  }
  throw new Error("expected the call to fail");
};

describe("Shift registration RPCs match the app's contract", () => {
  it("settings, board, submit, list and cancel", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const monday = await db.scalar<string>("select (date_trunc('week', current_date)::date + 14)::text");
      const template = await db.scalar<string>(
        "insert into public.shift_templates (branch_id, name, start_time, end_time) values ($1, 'Morning', time '08:00', time '12:00') returning id",
        [a.branch]
      );

      await db.signIn(a.staff);
      const closed = await fail(db, "select public.submit_shift_requests($1, $2::date, $3::jsonb)", [
        a.branch,
        monday,
        JSON.stringify([{ work_date: monday, template_id: template }]),
      ]);
      expect(attendanceErrorHint(closed)).toBe("registration_closed");

      await db.signOut();
      await db.signIn(a.manager);
      const rules = registrationRulesSchema.parse(
        await db.scalar("select public.save_shift_registration_settings($1, $2::jsonb)", [a.branch, JSON.stringify({ is_open: true, weeks_ahead: 3, max_shifts_per_week: 2, staff_note: "Hi" })])
      );
      expect(rules).toMatchObject({ is_open: true, weeks_ahead: 3, max_shifts_per_week: 2, staff_note: "Hi" });

      await db.signOut();
      await db.signIn(a.staff);
      registrationRulesSchema.parse(await db.scalar("select public.shift_registration_rules($1)", [a.branch]));
      const board = registrationBoardSchema.parse(await db.scalar("select public.shift_registration_board($1, $2::date)", [a.branch, monday]));
      expect(board.window.open).toBe(true);
      expect(board.templates).toHaveLength(1);
      expect(board.days).toHaveLength(7);

      const sent = submitResultSchema.parse(
        await db.scalar("select public.submit_shift_requests($1, $2::date, $3::jsonb, 'hi')", [a.branch, monday, JSON.stringify([{ work_date: monday, template_id: template }, { work_date: monday, template_id: template }])])
      );
      expect(sent.created).toHaveLength(1);
      expect(sent.skipped[0]?.hint).toBe("duplicate");

      const mine = myShiftRequestsSchema.parse(await db.scalar("select public.my_shift_requests($1::date, $1::date + 6)", [monday]));
      expect(mine[0]).toMatchObject({ status: "pending", expired: false, branch_name: "Branch ATC" });
      await db.scalar("select public.cancel_shift_request($1)", [mine[0]?.id]);
      const again = await fail(db, "select public.cancel_shift_request($1)", [mine[0]?.id]);
      expect(attendanceErrorHint(again)).toBe("not_pending");
    });
  });
});
