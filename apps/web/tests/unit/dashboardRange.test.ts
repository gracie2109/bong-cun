import { describe, expect, it, vi } from "vitest";

// The reports barrel pulls in the data layer; only its date maths is needed here.
vi.mock("@/features/admin/reports", () => import("@/features/admin/reports/shared/dateRange"));

import { bucketFor, rangeLabel, resolveRange } from "@/features/admin/dashboard/range/widgetRange";

const TODAY = "2026-10-23";

describe("resolveRange", () => {
  it("uses the default when nothing is set", () => {
    expect(resolveRange(undefined, "today", TODAY)).toEqual({ from: TODAY, to: TODAY });
    expect(resolveRange(undefined, "thisMonth", TODAY)).toEqual({ from: "2026-10-01", to: TODAY });
  });
  it("reads presets relative to today", () => {
    expect(resolveRange({ kind: "preset", preset: "last7" }, "today", TODAY)).toEqual({ from: "2026-10-17", to: TODAY });
    expect(resolveRange({ kind: "preset", preset: "last30" }, "today", TODAY)).toEqual({ from: "2026-09-24", to: TODAY });
    expect(resolveRange({ kind: "preset", preset: "lastMonth" }, "today", TODAY)).toEqual({ from: "2026-09-01", to: "2026-09-30" });
    expect(resolveRange({ kind: "preset", preset: "yesterday" }, "today", TODAY)).toEqual({ from: "2026-10-22", to: "2026-10-22" });
  });
  it("keeps a valid fixed range and falls back from an invalid one", () => {
    expect(resolveRange({ kind: "fixed", from: "2026-10-01", to: "2026-10-15" }, "today", TODAY)).toEqual({ from: "2026-10-01", to: "2026-10-15" });
    expect(resolveRange({ kind: "fixed", from: "2026-10-15", to: "2026-10-01" }, "last7", TODAY)).toEqual({ from: "2026-10-17", to: TODAY });
    expect(resolveRange({ kind: "fixed", from: "2025-01-01", to: "2026-10-01" }, "today", TODAY)).toEqual({ from: TODAY, to: TODAY });
  });
  it("accepts exactly 366 days and refuses 367", () => {
    expect(resolveRange({ kind: "fixed", from: "2025-10-23", to: "2026-10-23" }, "today", TODAY).from).toBe("2025-10-23");
    expect(resolveRange({ kind: "fixed", from: "2025-10-22", to: "2026-10-23" }, "today", TODAY).from).toBe(TODAY);
  });
});

describe("rangeLabel and bucketFor", () => {
  it("labels the preset in force, or the fixed dates", () => {
    expect(rangeLabel(undefined, "last7")).toEqual({ kind: "preset", preset: "last7" });
    expect(rangeLabel({ kind: "fixed", from: "2026-10-01", to: "2026-10-15" }, "today")).toEqual({ kind: "fixed", from: "2026-10-01", to: "2026-10-15" });
    expect(rangeLabel({ kind: "fixed", from: "2026-10-15", to: "2026-10-01" }, "today")).toEqual({ kind: "preset", preset: "today" });
  });
  it("buckets by day, week or month by length", () => {
    expect(bucketFor({ from: "2026-10-01", to: "2026-10-31" })).toBe("day");
    expect(bucketFor({ from: "2026-09-01", to: "2026-10-31" })).toBe("week");
    expect(bucketFor({ from: "2026-01-01", to: "2026-10-31" })).toBe("month");
  });
});
