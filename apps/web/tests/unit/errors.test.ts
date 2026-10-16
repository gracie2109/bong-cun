import { describe, expect, it } from "vitest";
import { AppError } from "@bongcun/core/shared";
import { toAppError } from "@bongcun/supabase/shared";

describe("toAppError", () => {
  it("maps the shared Postgres codes", () => {
    expect(toAppError({ code: "23505" })?.code).toBe("conflict");
    expect(toAppError({ code: "23503" })?.code).toBe("in_use");
    expect(toAppError({ code: "42501" })?.code).toBe("forbidden");
  });

  it("returns null for anything else", () => {
    expect(toAppError({ code: "P0001", message: "no_open_shift" })).toBeNull();
    expect(toAppError(new Error("boom"))).toBeNull();
    expect(toAppError(null)).toBeNull();
  });

  it("keeps an AppError as it is", () => {
    const error = new AppError("conflict");
    expect(toAppError(error)).toBe(error);
  });
});
