import { describe, expect, it } from "vitest";
import type { RegistrationBoard, RegistrationTemplate } from "@bongcun/core/attendance";
import { cellKey, cellState, remainingQuota, splitCellKey } from "@/features/admin/attendance/register/registerGrid";

const morning: RegistrationTemplate = { id: "t-morning", name: "Morning", startTime: "08:00", endTime: "12:00", breakMinutes: 0, color: "teal", overnight: false };
const night: RegistrationTemplate = { id: "t-night", name: "Night", startTime: "20:00", endTime: "06:00", breakMinutes: 0, color: "violet", overnight: true };
// 2026-11-16 is a Monday.
const MONDAY = "2026-11-16";

const board = (over: Partial<RegistrationBoard> = {}): RegistrationBoard => ({
  rules: { isOpen: true, weeksAhead: 2, closeDaysBefore: 2, maxShiftsPerWeek: null, staffNote: null, requirePublish: false },
  window: { open: true, closesAt: "2026-11-13T17:00:00+00:00", reason: null },
  templates: [morning, night],
  days: [MONDAY],
  requests: [],
  assignments: [],
  leaves: [],
  availability: [],
  needs: [],
  week: { requirePublish: false, status: "draft", publishedAt: null, publishedByName: null, autoPublished: false, pendingRequests: null, missingCount: null },
  submission: null,
  ...over,
});

describe("registration grid", () => {
  it("round-trips a cell key", () => {
    expect(splitCellKey(cellKey(MONDAY, "t-morning"))).toEqual({ workDate: MONDAY, templateId: "t-morning" });
  });

  it("an untouched cell can be ticked while the window is open, not after", () => {
    expect(cellState(board(), MONDAY, morning)).toMatchObject({ kind: "empty", selectable: true });
    expect(cellState(board({ window: { open: false, closesAt: "", reason: "past_deadline" } }), MONDAY, morning).selectable).toBe(false);
  });

  it("shows requests by status; a rejected cell can be asked again", () => {
    const request = { id: "r1", workDate: MONDAY, templateId: "t-morning", name: "Morning", note: null, decisionNote: "full", assignmentId: null, startAt: "2026-11-16T01:00:00Z", endAt: "2026-11-16T05:00:00Z" };
    expect(cellState(board({ requests: [{ ...request, status: "pending" }] }), MONDAY, morning)).toMatchObject({ kind: "pending", requestId: "r1", selectable: false });
    expect(cellState(board({ requests: [{ ...request, status: "approved" }] }), MONDAY, morning).kind).toBe("approved");
    expect(cellState(board({ requests: [{ ...request, status: "rejected" }] }), MONDAY, morning)).toMatchObject({ kind: "rejected", note: "full", selectable: true });
  });

  it("a decided request looks only 'sent' to staff until the week is published; a published week is locked", () => {
    const request = { id: "r1", workDate: MONDAY, templateId: "t-morning", name: "Morning", note: null, decisionNote: null, assignmentId: null, startAt: "2026-11-16T01:00:00Z", endAt: "2026-11-16T05:00:00Z" };
    expect(cellState(board({ requests: [{ ...request, status: "submitted" }] }), MONDAY, morning)).toMatchObject({ kind: "submitted", selectable: false });
    const published = { requirePublish: true, status: "published" as const, publishedAt: "2026-11-10T00:00:00Z", publishedByName: "M", autoPublished: false, pendingRequests: null, missingCount: null };
    expect(cellState(board({ week: published }), MONDAY, morning).selectable).toBe(false);
    // A branch that does not publish is never locked, whatever the status says.
    expect(cellState(board({ week: { ...published, requirePublish: false } }), MONDAY, morning).selectable).toBe(true);
  });

  it("marks shifts already on the roster, leave days and overlaps", () => {
    const assignment = { id: "a1", branchId: "b", branchName: "B", workDate: MONDAY, templateId: "t-morning", name: "Morning", startAt: "2026-11-16T01:00:00Z", endAt: "2026-11-16T05:00:00Z" };
    expect(cellState(board({ assignments: [assignment] }), MONDAY, morning).kind).toBe("onRoster");
    expect(cellState(board({ leaves: [{ fromDate: MONDAY, toDate: MONDAY, part: "full", leaveType: "annual" }] }), MONDAY, morning).kind).toBe("leave");
    // Another branch's shift 09:00-13:00 Vietnam time (02:00-06:00 UTC) overlaps the morning template.
    const other = { ...assignment, id: "a2", templateId: null, startAt: "2026-11-16T02:00:00Z", endAt: "2026-11-16T06:00:00Z" };
    expect(cellState(board({ assignments: [other] }), MONDAY, morning)).toMatchObject({ kind: "overlap", selectable: false });
    expect(cellState(board({ assignments: [other] }), MONDAY, night).kind).toBe("empty");
  });

  it("flags unavailable hours, including a night range that crosses midnight", () => {
    const wholeDay = [{ weekday: 1, kind: "unavailable" as const, startTime: null, endTime: null, note: null }];
    expect(cellState(board({ availability: wholeDay }), MONDAY, morning)).toMatchObject({ unavailable: true, selectable: true });
    const evening = [{ weekday: 1, kind: "unavailable" as const, startTime: "22:00", endTime: "04:00", note: null }];
    expect(cellState(board({ availability: evening }), MONDAY, night).unavailable).toBe(true);
    expect(cellState(board({ availability: evening }), MONDAY, morning).unavailable).toBe(false);
    const preferred = [{ weekday: 1, kind: "preferred" as const, startTime: null, endTime: null, note: null }];
    expect(cellState(board({ availability: preferred }), MONDAY, morning).unavailable).toBe(false);
  });

  it("counts the weekly quota left", () => {
    expect(remainingQuota(board(), "b")).toBeNull();
    const limited = board({
      rules: { isOpen: true, weeksAhead: 2, closeDaysBefore: 2, maxShiftsPerWeek: 3, staffNote: null },
      requests: [{ id: "r", workDate: MONDAY, templateId: "x", name: "x", status: "pending", note: null, decisionNote: null, assignmentId: null, startAt: "", endAt: "" }],
      assignments: [{ id: "a", branchId: "b", branchName: "B", workDate: MONDAY, templateId: null, name: "x", startAt: "", endAt: "" }],
    });
    expect(remainingQuota(limited, "b")).toBe(1);
    expect(remainingQuota(limited, "other")).toBe(2);
  });
});
