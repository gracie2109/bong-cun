import type { DashboardDef, DashboardKey, DashboardScope, ScopeKind, WidgetDef } from "./kit/types";

export type CanAt = (permission: string, branchId: string) => boolean;
export type WidgetAccess = "hidden" | "needsBranch" | "allowed";

type WidgetRule = Pick<WidgetDef, "permissions" | "scopes">;

const holdsAt = (permissions: readonly string[], branchId: string, canAt: CanAt) =>
  permissions.some((permission) => canAt(permission, branchId));

/**
 * Whether a widget is shown for the scope. The permission is checked at the branch being viewed
 * (or at some branch for "all"), never merged over every branch.
 */
export const widgetAccess = (widget: WidgetRule, scope: DashboardScope, canAt: CanAt): WidgetAccess => {
  if (scope.kind === "branch") {
    return scope.branchId && holdsAt(widget.permissions, scope.branchId, canAt) ? "allowed" : "hidden";
  }
  const somewhere = scope.branchIds.some((id) => holdsAt(widget.permissions, id, canAt));
  if (!somewhere) return "hidden";
  return widget.scopes.includes("all") ? "allowed" : "needsBranch";
};

/** The scope a dashboard really uses: "all" falls back to the working branch when it cannot answer. */
export const scopeFor = (dashboard: Pick<DashboardDef, "scopes">, scope: DashboardScope): DashboardScope =>
  dashboard.scopes.includes(scope.kind) ? scope : { ...scope, kind: "branch" };

/** A dashboard is offered when its required permission is held somewhere and a widget is visible. */
export const isDashboardVisible = (dashboard: DashboardDef, scope: DashboardScope, canAt: CanAt): boolean => {
  if (dashboard.requires && !scope.branchIds.some((id) => canAt(dashboard.requires as string, id))) return false;
  const used = scopeFor(dashboard, scope);
  return dashboard.widgets.some((widget) => widgetAccess(widget, used, canAt) !== "hidden");
};

export const visibleDashboards = (
  dashboards: readonly DashboardDef[],
  scope: DashboardScope,
  canAt: CanAt
): DashboardDef[] => dashboards.filter((dashboard) => isDashboardVisible(dashboard, scope, canAt));

/** The dashboard to open: the one in the URL, else the last used, else the first on offer. */
export const pickDashboard = (
  visible: readonly DashboardKey[],
  requested: unknown,
  stored: unknown
): DashboardKey | null => {
  const pick = (value: unknown) => visible.find((key) => key === value);
  return pick(requested) ?? pick(stored) ?? visible[0] ?? null;
};

export const SCOPE_KINDS: readonly ScopeKind[] = ["branch", "all"];
