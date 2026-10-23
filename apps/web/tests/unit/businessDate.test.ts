import { describe, expect, it } from "vitest";
import { businessDateOf, todayInVietnam } from "@/lib/businessDate";

describe("businessDate", () => {
  it("uses the Vietnam calendar, whatever the device clock", () => {
    expect(todayInVietnam(new Date("2026-10-23T16:59:00Z"))).toBe("2026-10-23");
    expect(todayInVietnam(new Date("2026-10-23T17:01:00Z"))).toBe("2026-10-24");
    expect(businessDateOf("2026-10-23T23:30:00+07:00")).toBe("2026-10-23");
  });
});
