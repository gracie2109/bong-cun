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

/** A widget placed on the default layout; the id is derived from the type (one per type). */
export type DefaultItem = { type: string; x: number; y: number; w: number; h: number };

/**
 * A starting layout for one kind of work. The first role whose `any` permission is held at some branch
 * and whose `lacks` permissions are held nowhere is used. Its items must be types of the dashboard's base layout.
 */
export type RoleDefault = {
  key: string;
  any: readonly string[];
  lacks?: readonly string[];
  items: readonly DefaultItem[];
};

export type DashboardKey = "today" | "business";

export type DashboardDef = {
  key: DashboardKey;
  titleKey: string;
  scopes: readonly ScopeKind[];
  /** A permission the account must hold at some branch before the dashboard is offered at all. */
  requires?: string;
  /** The layout a person sees until they save their own. */
  defaultItems: readonly DefaultItem[];
  /** Starting layouts for people who do not run the whole business; none matched = `defaultItems`. */
  roleDefaults?: readonly RoleDefault[];
};
