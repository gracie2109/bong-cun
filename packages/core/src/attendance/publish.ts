import type { WeekStatus } from "./publishTypes";

/** Whether staff may still send or cancel requests for the week: not once a publishing branch published it. */
export const staffCanEditWeek = (week: Pick<WeekStatus, "requirePublish" | "status">): boolean =>
  !(week.requirePublish && week.status === "published");

/** The line the publish dialog shows: how many people hear about it and which requests are closed. */
export type PublishSummary = { shifts: number; pendingRequests: number; missing: number };

export const publishWarnings = (summary: PublishSummary): ("empty" | "pending" | "missing")[] => {
  const warnings: ("empty" | "pending" | "missing")[] = [];
  if (summary.shifts === 0) warnings.push("empty");
  if (summary.pendingRequests > 0) warnings.push("pending");
  if (summary.missing > 0) warnings.push("missing");
  return warnings;
};

/** Hours until a deadline, rounded up; 0 once it passed. */
export const hoursUntil = (iso: string | null, now: number = Date.now()): number =>
  iso ? Math.max(0, Math.ceil((new Date(iso).getTime() - now) / 3_600_000)) : 0;
