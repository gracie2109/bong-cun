import { describe, expect, it } from "vitest";
import { shownBookingStatus } from "@bongcun/core/account";

describe("shownBookingStatus", () => {
  it("shows a booked visit whose time has passed as overdue", () => {
    expect(shownBookingStatus({ status: "booked", overdue: true })).toBe("overdue");
  });
  it("keeps the stored status otherwise", () => {
    expect(shownBookingStatus({ status: "booked", overdue: false })).toBe("booked");
    expect(shownBookingStatus({ status: "done", overdue: false })).toBe("done");
  });
});
