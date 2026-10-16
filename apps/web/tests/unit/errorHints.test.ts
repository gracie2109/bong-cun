import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { POS_ERROR_HINTS } from "@bongcun/core/pos";
import { SHOP_ERROR_HINTS } from "@bongcun/core/shop";
import { toAppError } from "@bongcun/supabase/shared";

const schema = readFileSync(fileURLToPath(new URL("../../../../supabase/schema.sql", import.meta.url)), "utf8");

/** Hints a function raises, read from its body in the generated schema. */
const hintsRaisedBy = (fn: string): string[] => {
  const body = new RegExp(`CREATE OR REPLACE FUNCTION "public"\\."${fn}"\\(.*?\\n\\$\\$;`, "s").exec(schema)?.[0];
  if (!body) throw new Error(`function ${fn} not found in supabase/schema.sql`);
  return [...new Set([...body.matchAll(/hint = '([a-z_]+)'/g)].map((match) => match[1]!))];
};

const MONEY_FUNCTIONS = [
  "create_invoice", "cancel_invoice", "create_sales_return", "open_cash_shift", "close_cash_shift",
  "place_shop_order", "confirm_shop_order", "pack_shop_order", "ship_shop_order", "deliver_shop_order",
  "return_shop_order", "cancel_shop_order", "cancel_my_shop_order", "pay_pickup_shop_order",
  "shop_order_for_update", "take_stock_fefo",
];

// Generic hints every module shares; they have no business code of their own.
const GENERIC = new Set(["not_found", "bad_input", "not_signed_in", "not_editable", "forbidden"]);

describe("error hints of the money flows", () => {
  const known = new Set<string>([...POS_ERROR_HINTS, ...SHOP_ERROR_HINTS]);

  it.each(MONEY_FUNCTIONS)("%s raises only hints that core names", (fn) => {
    const unknown = hintsRaisedBy(fn).filter((hint) => !known.has(hint) && !GENERIC.has(hint));
    expect(unknown).toEqual([]);
  });

  it("names no hint the database never raises", () => {
    const raised = new Set([...schema.matchAll(/hint = '([a-z_]+)'/g)].map((match) => match[1]!));
    expect([...known].filter((hint) => !raised.has(hint))).toEqual([]);
  });
});

describe("toAppError with hints", () => {
  it("uses the hint as the code", () => {
    expect(toAppError({ code: "P0001", hint: "no_open_shift" })?.code).toBe("no_open_shift");
    expect(toAppError({ code: "22023", hint: "cod_limit" })?.code).toBe("cod_limit");
  });

  it("lets the Postgres code win over a hint", () => {
    expect(toAppError({ code: "42501", hint: "out_of_stock" })?.code).toBe("forbidden");
  });

  it("ignores a hint nobody named", () => {
    expect(toAppError({ code: "P0001", hint: "something_new" })).toBeNull();
  });
});
