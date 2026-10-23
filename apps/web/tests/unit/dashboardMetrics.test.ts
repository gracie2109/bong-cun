import { describe, expect, it } from "vitest";
import { METRIC_LIST, metricOf } from "@/features/admin/dashboard/metrics/catalogue";
import { metricAccess, metricOfferedAt } from "@/features/admin/dashboard/metrics/metricAccess";
import { resolveParams } from "@/features/admin/dashboard/metrics/params";
import type { DashboardScope } from "@/features/admin/dashboard/kit/types";

const grants: Record<string, string[]> = { a: ["reports", "inventory"], b: ["boarding"] };
const canAt = (permission: string, branchId: string) => (grants[branchId] ?? []).includes(permission);
const branch = (branchId: string): DashboardScope => ({ kind: "branch", branchId, branchIds: ["a", "b"] });
const all: DashboardScope = { kind: "all", branchId: "a", branchIds: ["a", "b"] };

describe("catalogue", () => {
  it("has unique keys and a permission, source and view for every metric", () => {
    const keys = METRIC_LIST.map((metric) => metric.key);
    expect(new Set(keys).size).toBe(keys.length);
    for (const metric of METRIC_LIST) {
      expect(metric.permission, metric.key).toBeTruthy();
      expect(metric.views.length, metric.key).toBeGreaterThan(0);
      expect(metric.scopes.length, metric.key).toBeGreaterThan(0);
    }
  });

  it("lets only report metrics add up all branches", () => {
    for (const metric of METRIC_LIST) {
      expect(metric.scopes.includes("all"), metric.key).toBe(metric.permission === "reports");
    }
  });

  it("gives a date range only to report metrics, with a default", () => {
    for (const metric of METRIC_LIST) {
      expect(metric.usesRange, metric.key).toBe(metric.permission === "reports");
      if (metric.usesRange) expect(metric.defaultRange, metric.key).toBeTruthy();
    }
  });

  it("answers unknown keys with null, including inherited object keys", () => {
    expect(metricOf("revenue.net")?.key).toBe("revenue.net");
    expect(metricOf("nope")).toBeNull();
    expect(metricOf("constructor")).toBeNull();
    expect(metricOf("__proto__")).toBeNull();
  });
});

describe("resolveParams", () => {
  const net = metricOf("revenue.net")!;
  it("defaults to the first allowed value", () => {
    expect(resolveParams(net, undefined)).toEqual({ segment: "all" });
  });
  it("keeps an allowed value and refuses anything else", () => {
    expect(resolveParams(net, { segment: "spa" })).toEqual({ segment: "spa" });
    expect(resolveParams(net, { segment: "drop table" })).toBeNull();
    expect(resolveParams(net, { segment: 1 })).toBeNull();
  });
  it("ignores parameters the metric does not declare", () => {
    expect(resolveParams(metricOf("stock.low")!, { sql: "select 1" })).toEqual({});
  });
  it("keeps numeric parameters as numbers", () => {
    expect(resolveParams(metricOf("stock.expiring")!, { days: 30 })).toEqual({ days: 30 });
    expect(resolveParams(metricOf("stock.expiring")!, { days: "30" })).toBeNull();
  });
});

describe("metricAccess", () => {
  const revenue = metricOf("revenue.net")!;
  const stock = metricOf("stock.low")!;
  it("checks the permission at the branch in view", () => {
    expect(metricAccess(revenue, branch("a"), canAt)).toBe("allowed");
    expect(metricAccess(revenue, branch("b"), canAt)).toBe("hidden");
  });
  it("asks for one branch when a metric cannot add up all of them", () => {
    expect(metricAccess(revenue, all, canAt)).toBe("allowed");
    expect(metricAccess(stock, all, canAt)).toBe("needsBranch");
    expect(metricAccess(metricOf("boarding.today")!, all, canAt)).toBe("needsBranch");
  });
  it("offers a metric when the permission is held at any branch", () => {
    expect(metricOfferedAt(stock, ["a", "b"], canAt)).toBe(true);
    expect(metricOfferedAt(stock, ["b"], canAt)).toBe(false);
  });
});
