import {
  bookedAppointmentSchema,
  publicCatalogSchema,
  webQuoteSchema,
  webRulesSchema,
  webSlotsSchema,
} from "@bongcun/core/spa";
import { toAppError } from "@bongcun/supabase/shared";
import { describe, expect, it } from "vitest";
import { inRolledBackTransaction, type Session } from "./db";

const DAY_AFTER_TOMORROW = "((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)";

// A signed-in shop customer with one pet, one fixed-price service and two spa tables.
const setUpWebSpa = async (db: Session) => {
  const branch = await db.scalar<string>("select tests.create_branch('CT5')");
  const user = await db.scalar<string>("select tests.create_user('contract-web@test.local', 'customer')");
  const customer = await db.scalar<string>("select tests.create_patient('0900000402', 'Contract Web Pet')");
  await db.rows("update public.customers set user_id = $1 where id = $2", [user, customer]);
  const pet = await db.scalar<string>("select tests.pet_of($1)", [customer]);
  const service = await db.scalar<string>(
    "insert into public.pet_services (name, type, general_price, duration_minutes) values ('Contract web wash', 'all', 150000, 30) returning id"
  );
  await db.rows("insert into public.spa_resources (branch_id, name) values ($1, 'T1'), ($1, 'T2')", [branch]);
  const date = await db.scalar<string>(`select ${DAY_AFTER_TOMORROW}::text`);
  const startAt = await db.scalar<string>(
    `select to_char((((${DAY_AFTER_TOMORROW}) + time '10:00') at time zone 'Asia/Ho_Chi_Minh') at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')`
  );
  await db.signIn(user);
  return { branch, pet, service, date, startAt };
};

describe("Online spa booking RPCs match the app's contract", () => {
  it("catalog, rules, slots, quote and booking", async () => {
    await inRolledBackTransaction(async (db) => {
      const spa = await setUpWebSpa(db);

      const catalog = publicCatalogSchema.parse(await db.scalar("select public.spa_public_catalog($1)", [spa.branch]));
      expect(catalog.services.map((service) => service.name)).toContain("Contract web wash");

      const rules = webRulesSchema.parse(await db.scalar("select public.spa_web_rules()"));
      expect(rules.step_minutes).toBe(15);

      const slots = webSlotsSchema.parse(await db.scalar("select public.spa_web_slots($1, $2::date, 30)", [spa.branch, spa.date]));
      expect(slots.some((slot) => slot.free)).toBe(true);

      const items = [{ pet_id: spa.pet, type: "service", id: spa.service }];
      const quote = webQuoteSchema.parse(await db.scalar("select public.spa_web_quote($1, $2::jsonb)", [spa.branch, JSON.stringify(items)]));
      expect(quote.total_price).toBe(150_000);
      expect(quote.total_minutes).toBe(30);

      const booked = bookedAppointmentSchema.parse(
        await db.rpc("book_my_appointment", { branch_id: spa.branch, start_at: spa.startAt, note: "", items })
      );
      expect(booked.code).toMatch(/^LH/);
    });
  });

  it("booking the same pet twice at one time raises pet_busy", async () => {
    await inRolledBackTransaction(async (db) => {
      const spa = await setUpWebSpa(db);
      const request = {
        branch_id: spa.branch,
        start_at: spa.startAt,
        note: "",
        items: [{ pet_id: spa.pet, type: "service", id: spa.service }],
      };
      await db.rpc("book_my_appointment", request);
      const error = await db.rpc("book_my_appointment", request).catch((e: unknown) => e);
      expect(toAppError(error)?.code).toBe("pet_busy");
    });
  });
});
