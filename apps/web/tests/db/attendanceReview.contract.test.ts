import {
  attendanceErrorHint,
  decideRequestsResultSchema,
  rosterSchema,
  shiftRequestListSchema,
} from "@bongcun/core/attendance";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Shift request review RPCs match the app's contract", () => {
  it("list, decide, badge and the roster with requests", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const monday = await db.scalar<string>("select (date_trunc('week', current_date)::date + 14)::text");
      const template = await db.scalar<string>(
        "insert into public.shift_templates (branch_id, name, start_time, end_time) values ($1, 'Morning', time '08:00', time '12:00') returning id",
        [a.branch]
      );
      await db.rows("insert into public.shift_registration_settings (branch_id, is_open, weeks_ahead) values ($1, true, 3)", [a.branch]);

      await db.signIn(a.staff);
      await db.scalar("select public.submit_shift_requests($1, $2::date, $3::jsonb)", [a.branch, monday, JSON.stringify([{ work_date: monday, template_id: template }])]);
      await db.signOut();

      await db.signIn(a.manager);
      expect(Number(await db.scalar("select public.pending_shift_request_count($1)", [a.branch]))).toBe(1);
      const list = shiftRequestListSchema.parse(await db.scalar("select public.list_shift_requests($1, 'pending')", [a.branch]));
      expect(list.total).toBe(1);
      expect(list.rows[0]).toMatchObject({ status: "pending", expired: false, on_leave: false, availability: null, user_id: a.staff });

      const roster = rosterSchema.parse(await db.scalar("select public.shift_roster($1, $2::date, $2::date + 6)", [a.branch, monday]));
      expect(roster.requests).toHaveLength(1);

      const decided = decideRequestsResultSchema.parse(
        await db.scalar("select public.decide_shift_requests($1::uuid[], true, 'ok')", [[list.rows[0]?.id]])
      );
      expect(decided).toMatchObject({ approved: 1, rejected: 0, failed: [] });
      const after = shiftRequestListSchema.parse(await db.scalar("select public.list_shift_requests($1, 'approved')", [a.branch]));
      expect(after.rows[0]).toMatchObject({ status: "approved", on_roster: true });
      const again = decideRequestsResultSchema.parse(
        await db.scalar("select public.decide_shift_requests($1::uuid[], false)", [[list.rows[0]?.id]])
      );
      expect(attendanceErrorHint({ hint: again.failed[0]?.hint })).toBe("not_pending");
    });
  });
});
