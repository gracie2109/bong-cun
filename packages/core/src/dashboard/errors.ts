// The hints the dashboard layout RPCs attach to a refusal.
export const DASHBOARD_ERROR_HINTS = ["layout_invalid", "layout_conflict"] as const;
export type DashboardErrorHint = (typeof DASHBOARD_ERROR_HINTS)[number];

export const dashboardErrorHint = (error: unknown): DashboardErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return DASHBOARD_ERROR_HINTS.find((item) => item === hint) ?? null;
};
