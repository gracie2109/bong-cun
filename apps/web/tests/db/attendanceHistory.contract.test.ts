import { historyListSchema, historyOfSchema } from "@bongcun/core/attendance";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Schedule history RPCs match the app's contract", () => {
  it("lists a change with its reason and finds it again by entity", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const monday = await db.scalar<string>("select (date_trunc('week', current_date)::date + 14)::text");
      const template = await db.scalar<string>(
        "insert into public.shift_templates (branch_id, name, start_time, end_time) values ($1, 'Morning', time '08:00', time '12:00') returning id",
        [a.branch]
      );
      await db.signIn(a.manager);
      const made = await db.scalar<{ id: string }>("select public.assign_shift($1, $2, $3::date, $4, null, null, null, null, 'cover')", [a.branch, a.staff, monday, template]);
      const list = historyListSchema.parse(await db.scalar("select public.schedule_history_list($1)", [a.branch]));
      expect(list.total).toBe(1);
      expect(list.rows[0]).toMatchObject({ entity: "assignment", action: "insert", reason: "cover", source: "assign_shift", was_published: false });
      const of = historyOfSchema.parse(await db.scalar("select public.schedule_history_of('assignment', $1)", [made.id]));
      expect(of).toHaveLength(1);
      // The old call style, without a reason, still works.
      await db.scalar("select public.remove_shift_assignment($1)", [made.id]);
      expect(historyOfSchema.parse(await db.scalar("select public.schedule_history_of('assignment', $1)", [made.id]))).toHaveLength(2);
    });
  });
});
