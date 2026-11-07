import type { ShiftRequest } from "@bongcun/core/attendance";

/** The people who asked for the same shift on the same day, first come first served. */
export type RequestGroup = {
  key: string;
  workDate: string;
  startAt: string;
  endAt: string;
  name: string;
  color: ShiftRequest["color"];
  /** Earliest registration first: the order the manager should work through. */
  requests: ShiftRequest[];
  pendingIds: string[];
};

const byRegistration = (a: ShiftRequest, b: ShiftRequest) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id);

/** Groups requests by day and shift (same start, end and name) and orders each group by who registered first. */
export const groupRequests = (rows: ShiftRequest[]): RequestGroup[] => {
  const groups = new Map<string, RequestGroup>();
  for (const request of rows) {
    const key = `${request.workDate}|${request.startAt}|${request.endAt}|${request.name}`;
    const group = groups.get(key) ?? {
      key,
      workDate: request.workDate,
      startAt: request.startAt,
      endAt: request.endAt,
      name: request.name,
      color: request.color,
      requests: [],
      pendingIds: [],
    };
    group.requests.push(request);
    if (request.status === "pending") group.pendingIds.push(request.id);
    groups.set(key, group);
  }
  const list = [...groups.values()];
  for (const group of list) group.requests.sort(byRegistration);
  return list.sort((a, b) => a.workDate.localeCompare(b.workDate) || a.startAt.localeCompare(b.startAt) || a.name.localeCompare(b.name));
};
