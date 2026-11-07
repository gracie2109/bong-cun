import {
  assignShiftResultSchema,
  attendanceErrorHint,
  attendanceRulesSchema,
  copyWeekResultSchema,
  rosterSchema,
  shiftTemplateRowSchema,
} from "@bongcun/core/attendance";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

const template = (name: string, from: string, to: string) => JSON.stringify({ name, start_time: from, end_time: to });

describe("Attendance shift RPCs match the app's contract", () => {
  it("settings, templates, roster, assign, update, copy and remove", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      await db.signIn(a.manager);

      const rules = attendanceRulesSchema.parse(await db.scalar("select public.attendance_rules($1)", [a.branch]));
      expect(rules.review_after_hours).toBe(16);
      const saved = attendanceRulesSchema.parse(
        await db.scalar("select public.save_attendance_settings($1, $2::jsonb)", [a.branch, JSON.stringify({ allow_unscheduled: false })])
      );
      expect(saved.allow_unscheduled).toBe(false);

      const day = await db.scalar<string>("select public.save_shift_template($1, $2::jsonb)", [a.branch, template("Day", "08:00", "14:00")]);
      const night = await db.scalar<string>("select public.save_shift_template($1, $2::jsonb)", [a.branch, template("Night", "20:00", "08:00")]);
      const templates = await db.rows<{ list_shift_templates: unknown }>("select public.list_shift_templates($1)", [a.branch]);
      const parsed = templates.map((row) => shiftTemplateRowSchema.parse(row.list_shift_templates));
      expect(parsed.find((row) => row.id === night)?.overnight).toBe(true);

      const first = assignShiftResultSchema.parse(
        await db.scalar("select public.assign_shift($1, $2, $3::date, $4)", [a.branch, a.staff, a.monday, day])
      );
      assignShiftResultSchema.parse(
        await db.scalar("select public.assign_shift($1, $2, $3::date, $4)", [a.branch, a.other, a.monday, night])
      );
      await db.rows("select public.update_shift_assignment($1, $2::jsonb)", [first.id, JSON.stringify({ note: "Front desk", break_minutes: 15 })]);

      const roster = rosterSchema.parse(
        await db.scalar("select public.shift_roster($1, $2::date, $2::date + 6)", [a.branch, a.monday])
      );
      expect(roster.assignments).toHaveLength(2);
      expect(roster.assignments.find((row) => row.id === first.id)).toMatchObject({ note: "Front desk", break_minutes: 15, has_entry: false });
      expect(roster.staff.map((row) => row.user_id)).toContain(a.staff);

      const copy = copyWeekResultSchema.parse(
        await db.scalar("select public.copy_roster_week($1, $2::date, $2::date + 7)", [a.branch, a.monday])
      );
      expect(copy).toEqual({ copied: 2, skipped: 0, skipped_past: 0 });

      await db.rows("select public.remove_shift_assignment($1)", [first.id]);
      const after = rosterSchema.parse(
        await db.scalar("select public.shift_roster($1, $2::date, $2::date + 6)", [a.branch, a.monday])
      );
      expect(after.assignments).toHaveLength(1);
    });
  });

  it("every refusal carries a hint the app maps to a code", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      await db.signIn(a.manager);
      const day = await db.scalar<string>("select public.save_shift_template($1, $2::jsonb)", [a.branch, template("Day", "08:00", "14:00")]);

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

      await db.rows("select public.assign_shift($1, $2, $3::date, $4)", [a.branch, a.staff, a.monday, day]);
      const overlap = await fail("select public.assign_shift($1, $2, $3::date, null, '09:00'::time, '10:00'::time)", [a.branch, a.staff, a.monday]);
      expect(attendanceErrorHint(overlap)).toBe("shift_overlap");
      expect(toAppError(overlap)?.code).toBe("shift_overlap");

      const taken = await fail("select public.save_shift_template($1, $2::jsonb)", [a.branch, template("day", "10:00", "12:00")]);
      expect(toAppError(taken)?.code).toBe("name_taken");

      const notStaff = await fail("select public.assign_shift($1, $2, $3::date, $4)", [a.branch, a.outsider, a.monday, day]);
      expect(toAppError(notStaff)?.code).toBe("not_branch_staff");

      const tooLong = await fail("select public.shift_roster($1, $2::date, $2::date + 60)", [a.branch, a.monday]);
      expect(toAppError(tooLong)?.code).toBe("range_too_long");

      await db.signOut();
      await db.signIn(a.staff);
      const forbidden = await fail("select public.shift_roster($1, $2::date, $2::date)", [a.branch, a.monday]);
      expect(toAppError(forbidden)?.code).toBe("forbidden");
    });
  });
});
