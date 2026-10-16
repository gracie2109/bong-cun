import { describe, expect, it } from "vitest";
import { isCancellable, isEditable, isServing, spaErrorDetail, spaErrorHint } from "@bongcun/core/spa";

describe("spa appointment rules", () => {
  it("edits only booked appointments", () => {
    expect(isEditable("booked")).toBe(true);
    expect(isEditable("checked_in")).toBe(false);
  });

  it("cancels before the pet is serving", () => {
    expect(isCancellable("booked")).toBe(true);
    expect(isCancellable("checked_in")).toBe(true);
    expect(isServing("booked")).toBe(false);
  });

  it("reads the error hint the database raised", () => {
    expect(spaErrorHint({ hint: "bad_status" })).toBe("bad_status");
    expect(spaErrorHint({ hint: "something_else" })).toBeNull();
    expect(spaErrorHint(null)).toBeNull();
    expect(spaErrorDetail({ details: "Cắt tỉa" })).toBe("Cắt tỉa");
    expect(spaErrorDetail(null)).toBe("");
  });
});
