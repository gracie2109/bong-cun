import type { Component } from "vue";

/** Where a dashboard reads from: one branch, or every branch the account may see. */
export type ScopeKind = "branch" | "all";

export type DashboardScope = {
  kind: ScopeKind;
  /** The branch being worked at; stays set while the scope is "all" (the last one chosen). */
  branchId: string | undefined;
  /** Every branch offered to this account. */
  branchIds: string[];
};

/** What a widget shows, in the order the checks run. */
export type WidgetState = "hidden" | "needsBranch" | "loading" | "forbidden" | "error" | "empty" | "ready";

export type WidgetDef = {
  key: string;
  component: Component;
  /** Permission codes; the widget shows when the account holds any of them (VIEW) at the branch. */
  permissions: readonly string[];
  /** Scopes the widget can answer for. A widget without "all" asks for one branch instead. */
  scopes: readonly ScopeKind[];
  /** Grid columns on wide screens (default 1). */
  span?: 1 | 2;
};

export type DashboardKey = "today" | "business";

export type DashboardDef = {
  key: DashboardKey;
  titleKey: string;
  scopes: readonly ScopeKind[];
  /** A permission the account must hold at some branch before the dashboard is offered at all. */
  requires?: string;
  widgets: readonly WidgetDef[];
};
