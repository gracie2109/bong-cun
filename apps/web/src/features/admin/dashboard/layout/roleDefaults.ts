// Picks the starting layout of a dashboard for the person looking at it. Pure, so it can be tested.
import type { DashboardDef, DefaultItem } from "../kit/types";

/** Whether a permission is held at some branch the account works at. */
export type Holds = (permission: string) => boolean;

export const roleDefaultKey = (dashboard: Pick<DashboardDef, "roleDefaults">, holds: Holds): string | null =>
  dashboard.roleDefaults?.find((role) => role.any.some(holds) && !(role.lacks ?? []).some(holds))?.key ?? null;

/** The items to show until the person saves their own: their role's layout, else the dashboard's base one. */
export const defaultItemsFor = (
  dashboard: Pick<DashboardDef, "defaultItems" | "roleDefaults">,
  holds: Holds
): readonly DefaultItem[] => {
  const key = roleDefaultKey(dashboard, holds);
  return dashboard.roleDefaults?.find((role) => role.key === key)?.items ?? dashboard.defaultItems;
};
