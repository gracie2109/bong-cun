import { describe, expect, it } from "vitest";
import { notificationRoute } from "@bongcun/core/notifications";

describe("notificationRoute", () => {
  it("keeps a named route and its query", () => {
    expect(notificationRoute({ name: "attendanceMe", query: { week: "2026-11-17" } })).toEqual({
      name: "attendanceMe",
      query: { week: "2026-11-17" },
    });
  });
  it("returns null without a link or with a name that is not a route name", () => {
    expect(notificationRoute(null)).toBeNull();
    expect(notificationRoute({ name: "https://evil.example", query: {} })).toBeNull();
    expect(notificationRoute({ name: "/admin", query: {} })).toBeNull();
  });
});
