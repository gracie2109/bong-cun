import { describe, expect, it } from "vitest";
import { shownBookingStatus } from "@bongcun/core/account";

describe("shownBookingStatus", () => {
  it("shows a booked visit whose time has passed as overdue", () => {
    expect(shownBookingStatus({ status: "booked", overdue: true, expired: false })).toBe("overdue");
  });
  it("shows a booking the system cancelled for the time as expired", () => {
    expect(shownBookingStatus({ status: "cancelled", overdue: false, expired: true })).toBe("expired");
  });
  it("keeps the stored status otherwise", () => {
    expect(shownBookingStatus({ status: "booked", overdue: false, expired: false })).toBe("booked");
    expect(shownBookingStatus({ status: "done", overdue: false, expired: false })).toBe("done");
  });
});
