// Turns what is stored (or the dashboard's default) into the items a dashboard shows.
import type { ParsedLayout, SavedItem } from "@bongcun/core/dashboard";
import type { DashboardDef } from "../kit/types";
import { metaOf } from "../widgetTypes/meta";
import { clampItem, compactLayout } from "./layoutMath";

/** The id of a default item: one per type, e.g. "wspatoday", "wtrend00". Matches the id rule of a saved layout. */
export const defaultItemId = (type: string): string => `w${type.toLowerCase()}`.padEnd(8, "0");

export const defaultLayout = (dashboard: Pick<DashboardDef, "defaultItems">): SavedItem[] =>
  dashboard.defaultItems.map((item) => ({ ...item, id: defaultItemId(item.type) }));

export type ResolvedLayout = {
  items: SavedItem[];
  /** Stored items that were malformed and dropped. */
  broken: number;
  /** True when no usable stored layout exists and the default is shown. */
  isDefault: boolean;
};

/** The stored layout when there is a usable one, else the dashboard's default. Never throws. */
export const resolveLayout = (stored: ParsedLayout | null, dashboard: Pick<DashboardDef, "defaultItems">): ResolvedLayout =>
  stored ? { items: stored.items, broken: stored.broken, isDefault: false } : { items: defaultLayout(dashboard), broken: 0, isDefault: true };

/** What the grid draws: sizes kept inside their type's limits, then pulled up. Not saved by itself. */
export const toDisplayItems = (items: readonly SavedItem[]): SavedItem[] =>
  compactLayout(items.map((item) => clampItem(item, metaOf(item.type))));

/** True when two layouts place the same items the same way (order of the list does not matter). */
export const sameLayout = (a: readonly SavedItem[], b: readonly SavedItem[]): boolean => {
  if (a.length !== b.length) return false;
  const byId = new Map(b.map((item) => [item.id, JSON.stringify(item)]));
  return a.every((item) => byId.get(item.id) === JSON.stringify(item));
};
