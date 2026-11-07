import {
  attendanceErrorHint,
  publishResultSchema,
  registrationBoardSchema,
  registrationStatusSchema,
  weekStatusSchema,
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

describe("Schedule publishing RPCs match the app's contract", () => {
  it("status, who has not registered, publish and the locked week", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const monday = await db.scalar<string>("select (date_trunc('week', current_date)::date + 14)::text");
      const template = await db.scalar<string>(
        "insert into public.shift_templates (branch_id, name, start_time, end_time) values ($1, 'Morning', time '08:00', time '12:00') returning id",
        [a.branch]
      );

      await db.signIn(a.manager);
      await db.scalar("select public.save_shift_registration_settings($1, $2::jsonb)", [
        a.branch,
        JSON.stringify({ is_open: true, weeks_ahead: 4, close_days_before: 3, require_publish: true }),
      ]);
      const draft = weekStatusSchema.parse(await db.scalar("select public.schedule_week_status($1, $2::date)", [a.branch, monday]));
      expect(draft).toMatchObject({ require_publish: true, status: "draft", missing_count: 2 });
      const status = registrationStatusSchema.parse(await db.scalar("select public.registration_status($1, $2::date)", [a.branch, monday]));
      expect(status.rows.find((row) => row.user_id === a.staff)).toMatchObject({ state: "missing", must_register: true });
      expect(status.rows.find((row) => row.user_id === a.manager)).toMatchObject({ state: "manager", must_register: false });

      await db.signOut();
      await db.signIn(a.staff);
      await db.scalar("select public.declare_no_shifts($1, $2::date, 'away')", [a.branch, monday]);
      const board = registrationBoardSchema.parse(await db.scalar("select public.shift_registration_board($1, $2::date)", [a.branch, monday]));
      expect(board.submission).toMatchObject({ kind: "none", reason: "away" });
      expect(board.week.status).toBe("draft");

      await db.signOut();
      await db.signIn(a.manager);
      const published = publishResultSchema.parse(await db.scalar("select public.publish_schedule_week($1, $2::date)", [a.branch, monday]));
      expect(published).toMatchObject({ rejected: 0 });
      expect(published.notified).toBeGreaterThanOrEqual(2);
      const again = await fail(db, "select public.publish_schedule_week($1, $2::date)", [a.branch, monday]);
      expect(attendanceErrorHint(again)).toBe("already_published");

      await db.signOut();
      await db.signIn(a.staff);
      const locked = await fail(db, "select public.submit_shift_requests($1, $2::date, $3::jsonb)", [
        a.branch,
        monday,
        JSON.stringify([{ work_date: monday, template_id: template }]),
      ]);
      expect(attendanceErrorHint(locked)).toBe("week_published");
      expect(weekStatusSchema.parse(await db.scalar("select public.schedule_week_status($1, $2::date)", [a.branch, monday])).status).toBe("published");
    });
  });
});
