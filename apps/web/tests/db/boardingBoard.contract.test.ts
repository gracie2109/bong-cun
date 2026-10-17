import {
  boardSchema,
  boardingRulesRowSchema,
  kennelPageSchema,
  kennelTypePageSchema,
  publicCatalogSchema,
  savedStaySchema,
  stayRowSchema,
  timelineSchema,
} from "@bongcun/core/boarding";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction } from "./db";
import { payloadOf, setUpStay } from "./boardingFixture";

describe("Boarding board and settings RPCs match the app's contract", () => {
  it("board, calendar, kennel lists, settings and the public catalog", async () => {
    await inRolledBackTransaction(async (db) => {
      const s = await setUpStay(db);
      const saved = savedStaySchema.parse(await db.rpc("save_boarding_stay", payloadOf(s)));
      const day = s.arrive.slice(0, 10);

      const board = boardSchema.parse(await db.scalar("select public.boarding_board($1, $2::date)", [s.branch, day]));
      const kennel = board.kennels?.find((row) => row.code === "C1");
      expect(kennel?.purpose).toBe("boarding");
      expect(kennel?.pets?.length ?? 0).toBe(0);

      const timeline = timelineSchema.parse(await db.scalar("select public.boarding_timeline($1, $2::date, 7)", [s.branch, day]));
      expect(timeline.kennels?.find((row) => row.code === "C1")?.segments).toHaveLength(1);

      const kennels = kennelPageSchema.parse(await db.scalar("select public.list_kennels($1)", [s.branch]));
      expect(kennels.total).toBe(1);

      const types = kennelTypePageSchema.parse(await db.scalar("select public.list_kennel_types($1)", [s.branch]));
      expect(types.rows?.some((row) => row.id === s.type && row.night_price === 100_000)).toBe(true);

      const rules = boardingRulesRowSchema.parse(await db.scalar("select public.boarding_settings_get($1)", [s.branch]));
      expect(rules.check_in_from).toMatch(/^\d\d:\d\d$/);

      const catalog = publicCatalogSchema.parse(await db.scalar("select public.boarding_public_catalog($1)", [s.branch]));
      expect(catalog.branch?.id).toBe(s.branch);

      // The stay checks in, then the care log and an extra service answer in the detail.
      const stayPet = stayRowSchema.parse(await db.scalar("select public.get_boarding_stay($1)", [saved.id])).pets![0]!.id;
      const checkIn = [{ stay_pet_id: stayPet, weight_kg: 6, vaccine_checked: true }];
      await db.scalar("select public.check_in_boarding($1, $2::jsonb, null)", [saved.id, JSON.stringify(checkIn)]);
      await db.scalar("select public.add_care_log($1, $2::jsonb)", [
        stayPet,
        JSON.stringify({ kind: "meal", meal_eaten: "all", content: "Ate well", visible_to_customer: true }),
      ]);
      const detail = stayRowSchema.parse(await db.scalar("select public.get_boarding_stay($1)", [saved.id]));
      expect(detail.care_logs).toHaveLength(1);
      expect(detail.care_logs?.[0]?.meal_eaten).toBe("all");
    });
  });

  it("a kennel code used twice raises duplicate_code", async () => {
    await inRolledBackTransaction(async (db) => {
      const s = await setUpStay(db);
      const kennel = { branch_id: s.branch, kennel_type_id: s.type, code: "C1" };
      const error = await db.rpc("save_kennel", kennel).catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("duplicate_code");
    });
  });
});
