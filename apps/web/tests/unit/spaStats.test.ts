import { describe, expect, it } from "vitest";
import { countTickets, upcomingTickets } from "@/features/admin/dashboard/widgets/spa/spaStats";
import { allClear, sortRows, type ActionRow } from "@/features/admin/dashboard/widgets/actionItems/actionItems";
import type { BoardTicket } from "@bongcun/supabase/spa";

const ticket = (id: string, status: BoardTicket["status"], startAt: string) => ({ id, status, startAt }) as BoardTicket;

describe("spa counts", () => {
  const tickets = [
    ticket("1", "waiting", "2026-10-23T03:00:00Z"),
    ticket("2", "in_progress", "2026-10-23T04:00:00Z"),
    ticket("3", "done", "2026-10-23T01:00:00Z"),
    ticket("4", "cancelled", "2026-10-23T05:00:00Z"),
    ticket("5", "waiting", "2026-10-23T06:00:00Z"),
  ];

  it("counts the tickets by status", () => {
    expect(countTickets(tickets)).toEqual({ waiting: 2, inProgress: 1, done: 1, cancelled: 1 });
    expect(countTickets([])).toEqual({ waiting: 0, inProgress: 0, done: 0, cancelled: 0 });
  });

  it("lists the next open tickets from now on, earliest first", () => {
    expect(upcomingTickets(tickets, "2026-10-23T03:30:00Z").map((t) => t.id)).toEqual(["2", "5"]);
    expect(upcomingTickets(tickets, "2026-10-23T00:00:00Z", 2).map((t) => t.id)).toEqual(["1", "2"]);
  });
});

describe("action rows", () => {
  const row = (count: number | null, failed = false) => ({ key: "stockLow", count, failed, to: "" }) as unknown as ActionRow;

  it("puts rows with work first and keeps their order", () => {
    const sorted = sortRows([row(0), row(3), row(null), row(1)]);
    expect(sorted.map((r) => r.count)).toEqual([3, 1, 0, null]);
  });

  it("is clear only when every source answered with zero", () => {
    expect(allClear([row(0), row(0)])).toBe(true);
    expect(allClear([row(0), row(null)])).toBe(false);
    expect(allClear([row(0), row(null, true)])).toBe(false);
    expect(allClear([])).toBe(false);
  });
});
