import { describe, expect, it } from "vitest";
import type { ShiftRequest } from "@bongcun/core/attendance";
import { groupRequests } from "@/features/admin/attendance/requests/groupRequests";

const request = (id: string, workDate: string, startAt: string, name: string, createdAt: string, status: ShiftRequest["status"] = "pending") =>
  ({ id, workDate, startAt, endAt: startAt, name, color: "teal", createdAt, status }) as unknown as ShiftRequest;

describe("groupRequests", () => {
  it("groups by day and shift and puts who registered first on top", () => {
    const groups = groupRequests([
      request("c", "2026-11-09", "2026-11-09T00:30:00Z", "Sang", "2026-11-05T10:00:00Z"),
      request("a", "2026-11-09", "2026-11-09T00:30:00Z", "Sang", "2026-11-05T08:00:00Z"),
      request("b", "2026-11-09", "2026-11-09T00:30:00Z", "Sang", "2026-11-05T09:00:00Z"),
      request("d", "2026-11-09", "2026-11-09T09:30:00Z", "Toi", "2026-11-05T07:00:00Z"),
    ]);
    expect(groups.map((group) => group.name)).toEqual(["Sang", "Toi"]);
    expect(groups[0]?.requests.map((item) => item.id)).toEqual(["a", "b", "c"]);
  });

  it("orders groups by day then start time and counts only pending ones for ticking", () => {
    const groups = groupRequests([
      request("x", "2026-11-10", "2026-11-10T00:30:00Z", "Sang", "2026-11-05T08:00:00Z", "approved"),
      request("y", "2026-11-10", "2026-11-10T00:30:00Z", "Sang", "2026-11-05T09:00:00Z"),
      request("z", "2026-11-09", "2026-11-09T09:30:00Z", "Toi", "2026-11-05T07:00:00Z"),
    ]);
    expect(groups.map((group) => group.workDate)).toEqual(["2026-11-09", "2026-11-10"]);
    expect(groups[1]?.pendingIds).toEqual(["y"]);
  });
});
