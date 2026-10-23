import { describe, expect, it } from "vitest";
import { isDashboardVisible, pickDashboard, scopeFor, visibleDashboards, widgetAccess } from "@/features/admin/dashboard/dashboardRules";
import type { DashboardDef, DashboardScope, WidgetDef } from "@/features/admin/dashboard/kit/types";

const grants: Record<string, string[]> = { a: ["medical", "reports"], b: ["boarding"] };
const canAt = (permission: string, branchId: string) => (grants[branchId] ?? []).includes(permission);
const widget = (permissions: string[], scopes: WidgetDef["scopes"] = ["branch"]) =>
  ({ key: permissions.join(), component: {}, permissions, scopes }) as WidgetDef;
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
    key: "today", titleKey: "t", scopes: ["branch"], widgets: [widget(["medical"]), widget(["boarding"])],
  };
  const business: DashboardDef = {
    key: "business", titleKey: "b", scopes: ["branch", "all"], requires: "reports", widgets: [widget(["reports"], ["branch", "all"])],
  };

  it("falls back to the working branch when a dashboard has no all-branch view", () => {
    expect(scopeFor(today, allScope).kind).toBe("branch");
    expect(scopeFor(business, allScope).kind).toBe("all");
  });

  it("offers a dashboard only with a visible widget and its required permission", () => {
    expect(visibleDashboards([today, business], branchScope("a"), canAt).map((d) => d.key)).toEqual(["today", "business"]);
    expect(visibleDashboards([today, business], branchScope("b"), canAt).map((d) => d.key)).toEqual(["today"]);
    expect(isDashboardVisible(business, { kind: "branch", branchId: "a", branchIds: [] }, canAt)).toBe(false);
  });

  it("picks the requested dashboard, then the stored one, then the first", () => {
    expect(pickDashboard(["today", "business"], "business", "today")).toBe("business");
    expect(pickDashboard(["today", "business"], "nope", "business")).toBe("business");
    expect(pickDashboard(["today"], "business", "business")).toBe("today");
    expect(pickDashboard([], "today", null)).toBeNull();
  });
});
