import { attendanceErrorHint, availabilityListSchema } from "@bongcun/core/attendance";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Availability RPCs match the app's contract", () => {
  it("save, read back, manager read and edit", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      const items = JSON.stringify([
        { weekday: 2, kind: "unavailable", start_time: null, end_time: null, note: null },
        { weekday: 6, kind: "preferred", start_time: "08:00", end_time: "14:00", note: "mornings" },
      ]);

      await db.signIn(a.staff);
      const saved = availabilityListSchema.parse(await db.scalar("select public.save_my_availability($1::jsonb)", [items]));
      expect(saved).toHaveLength(2);
      expect(saved[1]).toMatchObject({ weekday: 6, kind: "preferred", start_time: "08:00", end_time: "14:00", note: "mornings" });
      expect(availabilityListSchema.parse(await db.scalar("select public.my_availability()"))).toHaveLength(2);

      await db.signOut();
      await db.signIn(a.manager);
      expect(availabilityListSchema.parse(await db.scalar("select public.staff_availability_of($1)", [a.staff]))).toHaveLength(2);
      const edited = availabilityListSchema.parse(
        await db.scalar("select public.save_staff_availability($1, $2::jsonb)", [a.staff, JSON.stringify([{ weekday: 1, kind: "unavailable" }])])
      );
      expect(edited).toHaveLength(1);
      expect(edited[0]).toMatchObject({ weekday: 1, start_time: null });

      await db.signOut();
      await db.signIn(a.staff);
      await db.rows("savepoint attempt");
      const tooMany = await db
        .scalar("select public.save_my_availability((select jsonb_agg(jsonb_build_object('weekday', 1, 'kind', 'unavailable')) from generate_series(1, 22)))")
        .catch((error: unknown) => error);
      await db.rows("rollback to savepoint attempt");
      expect(attendanceErrorHint(tooMany)).toBe("too_many");
    });
  });
});
