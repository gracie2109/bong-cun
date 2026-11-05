import {
  attendanceErrorHint,
  decideLeaveResultSchema,
  leaveBalanceSchema,
  leaveListSchema,
  myLeaveSchema,
  requestLeaveResultSchema,
  rosterSchema,
} from "@bongcun/core/attendance";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Attendance leave RPCs match the app's contract", () => {
  it("file, list, decide, balance and the roster", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const sunday = await db.scalar<string>("select ($1::date + 6)::text", [a.monday]);

      await db.signIn(a.staff);
      const filed = requestLeaveResultSchema.parse(
        await db.scalar("select public.request_leave($1, 'annual', $2::date, $3::date, 'full', 'Trip')", [a.branch, a.monday, sunday])
      );
      expect(filed.days).toBe(7);
      const mine = myLeaveSchema.parse(await db.scalar("select public.my_leave_requests($1)", [Number(a.monday.slice(0, 4))]));
      expect(mine.requests[0]).toMatchObject({ id: filed.id, status: "pending", created_by_self: true });
      expect(mine.balance.allowance).toBe(12);

      await db.signOut();
      await db.signIn(a.manager);
      const list = leaveListSchema.parse(await db.scalar("select public.list_leave_requests($1, 'pending')", [a.branch]));
      expect(list.total).toBe(1);
      const decided = decideLeaveResultSchema.parse(await db.scalar("select public.decide_leave($1, true, 'ok')", [filed.id]));
      expect(decided).toMatchObject({ status: "approved", days: 7 });
      const balance = leaveBalanceSchema.parse(await db.scalar("select public.leave_balance($1, $2)", [a.staff, Number(a.monday.slice(0, 4))]));
      expect(balance.used).toBe(7);
      expect(Number(await db.scalar("select public.pending_leave_count($1)", [a.branch]))).toBe(0);

      const roster = rosterSchema.parse(await db.scalar("select public.shift_roster($1, $2::date, $2::date + 6)", [a.branch, a.monday]));
      expect(roster.leaves).toHaveLength(1);
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
      await db.rows("select public.request_leave($1, 'sick', $2::date, $2::date, 'full', 'Ill')", [a.branch, a.monday]);
      const overlap = await fail("select public.request_leave($1, 'sick', $2::date, $2::date, 'full', 'Again')", [a.branch, a.monday]);
      expect(attendanceErrorHint(overlap)).toBe("leave_overlap");
      const old = await fail("select public.request_leave($1, 'sick', current_date - 30, current_date - 30, 'full', 'Old')", [a.branch]);
      expect(toAppError(old)?.code).toBe("too_old");
      const own = await fail("select public.decide_leave((select id from public.leave_requests limit 1), true)", []);
      expect(toAppError(own)?.code).toBe("forbidden");
    });
  });
});
