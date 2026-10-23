import { widgetAccess, type CanAt, type WidgetAccess } from "../dashboardRules";
import type { DashboardScope } from "../kit/types";
import type { MetricDef } from "./types";

/**
 * Whether a metric shows for the scope: the same rule as a fixed widget, with the metric's one
 * permission. The database refuses the call anyway; this only decides what to draw.
 */
export const metricAccess = (def: Pick<MetricDef, "permission" | "scopes">, scope: DashboardScope, canAt: CanAt): WidgetAccess =>
  widgetAccess({ permissions: [def.permission], scopes: def.scopes }, scope, canAt);

/** True when the account holds the metric's permission at some branch it works at (for the "Add" list). */
export const metricOfferedAt = (def: Pick<MetricDef, "permission">, branchIds: readonly string[], canAt: CanAt): boolean =>
  branchIds.some((id) => canAt(def.permission, id));
