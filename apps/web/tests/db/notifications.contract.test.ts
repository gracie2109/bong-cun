import { notificationPageSchema } from "@bongcun/core/notifications";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { setUpAttendance } from "./attendanceFixture";

describe("Notification RPCs match the app's contract", () => {
  it("lists, counts and marks read", async () => {
    await inRolledBackTransaction(async (db) => {
      const a = await setUpAttendance(db);
      await db.scalar("select public.notify_user($1, $2, 'publish_reminder', 'Hi', 'body', $3::jsonb)", [
        a.staff,
        a.branch,
        JSON.stringify({ name: "attendanceMe", query: { week: "2026-11-17" } }),
      ]);
      await db.signIn(a.staff);
      const page = notificationPageSchema.parse(await db.scalar("select public.my_notifications(1, 20, false)"));
      expect(page).toMatchObject({ total: 1, unread: 1 });
      expect(page.rows[0]).toMatchObject({ kind: "publish_reminder", link: { name: "attendanceMe" } });
      expect(Number(await db.scalar("select public.unread_notification_count()"))).toBe(1);
      expect(Number(await db.scalar("select public.mark_notifications_read(null)"))).toBe(1);
      expect(Number(await db.scalar("select public.unread_notification_count()"))).toBe(0);
    });
  });
});
