import { describe, expect, it } from "vitest";
import { isDashboardVisible, pickDashboard, scopeFor, visibleDashboards, widgetAccess } from "@/features/admin/dashboard/dashboardRules";
import type { DashboardDef, DashboardScope } from "@/features/admin/dashboard/kit/types";
import type { WidgetTypeMeta } from "@/features/admin/dashboard/widgetTypes/types";

const grants: Record<string, string[]> = { a: ["medical", "reports"], b: ["boarding"] };
const canAt = (permission: string, branchId: string) => (grants[branchId] ?? []).includes(permission);
type Rule = Pick<WidgetTypeMeta, "permissions" | "scopes">;
const widget = (permissions: string[], scopes: Rule["scopes"] = ["branch"]): Rule => ({ permissions, scopes });
// Test dashboards place fake types "m", "b" and "r"; this looks their rules up.
const rules: Record<string, Rule> = { m: widget(["medical"]), b: widget(["boarding"]), r: widget(["reports"], ["branch", "all"]) };
const ruleOf = (type: string) => rules[type] ?? null;
const placed = (...types: string[]) => types.map((type, y) => ({ type, x: 0, y, w: 1, h: 1 }));
const branchScope = (branchId: string): DashboardScope => ({ kind: "branch", branchId, branchIds: ["a", "b"] });
const allScope: DashboardScope = { kind: "all", branchId: "a", branchIds: ["a", "b"] };

describe("widgetAccess", () => {
  it("checks the permission at the branch being viewed", () => {
    expect(widgetAccess(widget(["medical"]), branchScope("a"), canAt)).toBe("allowed");
    expect(widgetAccess(widget(["medical"]), branchScope("b"), canAt)).toBe("hidden");
    expect(widgetAccess(widget(["medical", "boarding"]), branchScope("b"), canAt)).toBe("allowed");
    expect(widgetAccess(widget(["medical"]), { ...branchScope("a"), branchId: undefined }, canAt)).toBe("hidden");
  });

  it("asks for one branch when the widget cannot add up all of them", () => {
    expect(widgetAccess(widget(["medical"]), allScope, canAt)).toBe("needsBranch");
    expect(widgetAccess(widget(["reports"], ["branch", "all"]), allScope, canAt)).toBe("allowed");
    expect(widgetAccess(widget(["pos"], ["branch", "all"]), allScope, canAt)).toBe("hidden");
  });
});

describe("dashboards", () => {
  const today: DashboardDef = {
    key: "today", titleKey: "t", scopes: ["branch"], defaultItems: placed("m", "b"),
  };
  const business: DashboardDef = {
    key: "business", titleKey: "b", scopes: ["branch", "all"], requires: "reports", defaultItems: placed("r"),
  };

  it("falls back to the working branch when a dashboard has no all-branch view", () => {
    expect(scopeFor(today, allScope).kind).toBe("branch");
    expect(scopeFor(business, allScope).kind).toBe("all");
  });

  it("offers a dashboard only with a visible widget and its required permission", () => {
    expect(visibleDashboards([today, business], branchScope("a"), canAt, ruleOf).map((d) => d.key)).toEqual(["today", "business"]);
    expect(visibleDashboards([today, business], branchScope("b"), canAt, ruleOf).map((d) => d.key)).toEqual(["today"]);
    expect(isDashboardVisible(business, { kind: "branch", branchId: "a", branchIds: [] }, canAt, ruleOf)).toBe(false);
  });

  it("picks the requested dashboard, then the stored one, then the first", () => {
    expect(pickDashboard(["today", "business"], "business", "today")).toBe("business");
    expect(pickDashboard(["today", "business"], "nope", "business")).toBe("business");
    expect(pickDashboard(["today"], "business", "business")).toBe("today");
    expect(pickDashboard([], "today", null)).toBeNull();
  });
});
