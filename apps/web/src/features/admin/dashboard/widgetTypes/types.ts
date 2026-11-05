import type { Component } from "vue";
import type { ScopeKind } from "../kit/types";

export type WidgetSize = { w: number; h: number };

/** Everything about a widget type except its component, so rules and layout maths stay free of Vue. */
export type WidgetTypeMeta = {
  key: string;
  /** Permission codes; the widget shows when the account holds any of them (VIEW) at the branch. */
  permissions: readonly string[];
  /** Scopes the widget can answer for. A widget without "all" asks for one branch instead. */
  scopes: readonly ScopeKind[];
  defaultSize: WidgetSize;
  minSize: WidgetSize;
  maxSize: WidgetSize;
  /** True when the widget shows the account's own data, so any role at the branch is enough. */
  anyStaff?: boolean;
  /** True for the types that show a catalogue metric: permission and scopes come from the metric. */
  byMetric?: boolean;
  /** Whether the same type may be placed more than once (a fixed widget may not). */
  multiple?: boolean;
};

export type WidgetTypeDef = WidgetTypeMeta & { component: Component };
