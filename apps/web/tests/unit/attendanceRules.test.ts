import { describe, expect, it } from "vitest";
import { formatMinutes, isOvernight, shiftLengthMinutes } from "@bongcun/core/attendance";

describe("shift length", () => {
  it("measures a day shift", () => {
    expect(shiftLengthMinutes("08:00", "14:00")).toBe(360);
    expect(isOvernight("08:00", "14:00")).toBe(false);
  });

  it("measures a shift that ends the next morning", () => {
    expect(shiftLengthMinutes("20:00", "08:00")).toBe(720);
    expect(isOvernight("20:00", "08:00")).toBe(true);
  });
});

describe("formatMinutes", () => {
  it("writes hours and minutes the way staff say them", () => {
    expect(formatMinutes(192)).toBe("3g12p");
    expect(formatMinutes(60)).toBe("1g");
    expect(formatMinutes(7)).toBe("7p");
    expect(formatMinutes(0)).toBe("0p");
    expect(formatMinutes(-5)).toBe("0p");
  });
});
