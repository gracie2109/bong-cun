// Pure: what each cell of the registration grid (a day and a shift template) looks like and whether it can be ticked.
import { addDays, isoWeekday } from "@bongcun/core/attendance";
import type { RegistrationBoard, RegistrationTemplate } from "@bongcun/core/attendance";

export type CellKind = "empty" | "pending" | "approved" | "rejected" | "onRoster" | "leave" | "overlap";

export type CellState = {
  kind: CellKind;
  /** The request on this cell, for cancelling it or reading the manager's note. */
  requestId: string | null;
  note: string | null;
  /** The person marked this day or hour as unavailable (still tickable, with a warning). */
  unavailable: boolean;
  /** Can be ticked now: empty or rejected, window open, no clash. */
  selectable: boolean;
};

export const cellKey = (date: string, templateId: string) => `${date}|${templateId}`;
export const splitCellKey = (key: string) => {
  const [workDate = "", templateId = ""] = key.split("|");
  return { workDate, templateId };
};

// Vietnam has no daylight saving, so a fixed offset gives the instant of a wall-clock time.
const instant = (date: string, time: string) => new Date(`${date}T${time}:00+07:00`).getTime();

/** Start and end (ms) of a template on a date; an overnight template ends the next day. */
export const templateSpan = (template: Pick<RegistrationTemplate, "startTime" | "endTime" | "overnight">, date: string) => ({
  start: instant(date, template.startTime),
  end: instant(template.overnight ? addDays(date, 1) : date, template.endTime),
});

const overlaps = (a: { start: number; end: number }, startAt: string, endAt: string) =>
  a.start < new Date(endAt).getTime() && a.end > new Date(startAt).getTime();

const isUnavailable = (board: RegistrationBoard, template: RegistrationTemplate, date: string): boolean => {
  const span = templateSpan(template, date);
  return board.availability.some((item) => {
    if (item.kind !== "unavailable" || item.weekday !== isoWeekday(date)) return false;
    if (!item.startTime || !item.endTime) return true;
    const overnight = item.endTime <= item.startTime;
    const range = { start: instant(date, item.startTime), end: instant(overnight ? addDays(date, 1) : date, item.endTime) };
    return range.start < span.end && range.end > span.start;
  });
};

const coveredByLeave = (board: RegistrationBoard, date: string) =>
  board.leaves.some((leave) => leave.fromDate <= date && leave.toDate >= date);

export const cellState = (board: RegistrationBoard, date: string, template: RegistrationTemplate): CellState => {
  const request = board.requests.find((r) => r.workDate === date && r.templateId === template.id);
  const base = { requestId: request?.id ?? null, note: request?.decisionNote ?? null, unavailable: isUnavailable(board, template, date) };
  const fixed = (kind: CellKind): CellState => ({ ...base, kind, selectable: false });

  if (request?.status === "pending") return fixed("pending");
  if (request?.status === "approved") return fixed("approved");
  const span = templateSpan(template, date);
  const same = board.assignments.find((a) => a.workDate === date && a.templateId === template.id);
  if (same) return fixed("onRoster");
  if (coveredByLeave(board, date)) return fixed("leave");
  const clashes =
    board.assignments.some((a) => overlaps(span, a.startAt, a.endAt)) ||
    board.requests.some((r) => r.status === "pending" && overlaps(span, r.startAt, r.endAt));
  if (clashes) return fixed("overlap");
  const kind: CellKind = request?.status === "rejected" ? "rejected" : "empty";
  return { ...base, kind, selectable: board.window.open };
};

/** How many ticked cells a person may still add this week: the limit minus alive requests and roster shifts at the branch. */
export const remainingQuota = (board: RegistrationBoard, branchId: string): number | null => {
  const limit = board.rules.maxShiftsPerWeek;
  if (limit === null) return null;
  const alive = board.requests.filter((r) => r.status === "pending").length;
  const onRoster = board.assignments.filter((a) => a.branchId === branchId).length;
  return Math.max(0, limit - alive - onRoster);
};
