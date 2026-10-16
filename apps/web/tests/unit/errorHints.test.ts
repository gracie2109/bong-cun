import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { GENERIC_HINTS, HINT_MODULES, KNOWN_UNRAISED } from "./errorHintModules";
import { toAppError } from "@bongcun/supabase/shared";

const schema = readFileSync(fileURLToPath(new URL("../../../../supabase/schema.sql", import.meta.url)), "utf8");

/** Hints a function raises, read from its body in the generated schema. */
/** Every hint a `hint =` line can produce, also when it is picked by a `case` expression. */
const raisedHints = new Set(
  [...schema.matchAll(/hint = [^\n]*/g)].flatMap((line) => [...line[0].matchAll(/'([a-z_]+)'/g)].map((match) => match[1]!))
);

const hintsRaisedBy = (fn: string): string[] => {
  const body = new RegExp(`CREATE OR REPLACE FUNCTION "public"\\."${fn}"\\(.*?\\n\\$_?\\$;`, "s").exec(schema)?.[0];
  if (!body) throw new Error(`function ${fn} not found in supabase/schema.sql`);
  return [...new Set([...body.matchAll(/hint = '([a-z_]+)'/g)].map((match) => match[1]!))];
};

describe.each(HINT_MODULES)("error hints of $module", ({ hints, functions }) => {
  const known = new Set<string>(hints);

  it.each(functions)("%s raises only hints that core names", (fn) => {
    const unknown = hintsRaisedBy(fn).filter((hint) => !known.has(hint) && !GENERIC_HINTS.has(hint));
    expect(unknown).toEqual([]);
  });

  it("names no hint the database never raises", () => {
    const dead = [...known].filter((hint) => !raisedHints.has(hint) && !KNOWN_UNRAISED.has(hint));
    expect(dead).toEqual([]);
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

  it("reads the hints of inventory, spa, boarding and medical", () => {
    expect(toAppError({ code: "P0001", hint: "lot_short" })?.code).toBe("lot_short");
    expect(toAppError({ code: "P0001", hint: "slot_staff" })?.code).toBe("slot_staff");
    expect(toAppError({ code: "P0001", hint: "kennel_taken" })?.code).toBe("kennel_taken");
    expect(toAppError({ code: "P0001", hint: "no_vaccine" })?.code).toBe("no_vaccine");
  });

  it("ignores a hint nobody named", () => {
    expect(toAppError({ code: "P0001", hint: "something_new" })).toBeNull();
  });
});
