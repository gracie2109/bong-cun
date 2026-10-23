import { describe, expect, it } from "vitest";
import { petCounts } from "@/features/admin/dashboard/widgets/boarding/boardingStats";

const pet = (over: Record<string, unknown> = {}) => ({ overdue: false, plannedOutAt: "2026-10-30T05:00:00Z", ...over });
const kennel = (pets: unknown[], arriving: unknown[] = []) => ({ pets, arriving });

describe("petCounts", () => {
  it("counts every pet in a shared kennel", () => {
    const board = { date: "2026-10-23", kennels: [kennel([pet(), pet(), pet()]), kennel([pet()])] };
    expect(petCounts(board as never).occupied).toBe(4);
  });

  it("separates overdue and departing pets and counts arrivals", () => {
    const board = {
      date: "2026-10-23",
      kennels: [
        kennel([pet({ overdue: true }), pet({ plannedOutAt: "2026-10-23T05:00:00Z" })], [pet(), pet()]),
        kennel([pet({ overdue: true, plannedOutAt: "2026-10-23T05:00:00Z" })]),
      ],
    };
    expect(petCounts(board as never)).toEqual({ arriving: 2, departing: 1, occupied: 3, overdue: 2 });
  });
});
