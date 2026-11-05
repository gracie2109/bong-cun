import type { LeavePart, LeaveType, RequestLeaveForInput, RequestLeaveInput } from "@bongcun/core/attendance";

export type LeaveDraft = {
  branchId: string;
  userId: string;
  leaveType: LeaveType;
  fromDate: string;
  toDate: string;
  part: LeavePart;
  reason: string;
};

export const LEAVE_TYPES: LeaveType[] = ["annual", "sick", "unpaid", "other"];
export const LEAVE_PARTS: LeavePart[] = ["full", "am", "pm"];

export const emptyLeaveDraft = (branchId: string, today: string): LeaveDraft => ({
  branchId,
  userId: "",
  leaveType: "annual",
  fromDate: today,
  toDate: today,
  part: "full",
  reason: "",
});

export type LeaveDraftError = "dates_required" | "range_invalid" | "reason_required" | "staff_required" | "branch_required";

export const leaveDraftError = (draft: LeaveDraft, needsStaff: boolean): LeaveDraftError | null => {
  if (!draft.branchId) return "branch_required";
  if (needsStaff && !draft.userId) return "staff_required";
  if (!draft.fromDate || !draft.toDate) return "dates_required";
  if (draft.toDate < draft.fromDate) return "range_invalid";
  if (!draft.reason.trim()) return "reason_required";
  return null;
};

/** Half days only exist for a single day; a longer range is always whole days. */
export const effectivePart = (draft: LeaveDraft): LeavePart => (draft.fromDate === draft.toDate ? draft.part : "full");

export const toRequestInput = (draft: LeaveDraft): RequestLeaveInput => ({
  branchId: draft.branchId,
  leaveType: draft.leaveType,
  fromDate: draft.fromDate,
  toDate: draft.toDate,
  part: effectivePart(draft),
  reason: draft.reason.trim(),
});

export const toRequestForInput = (draft: LeaveDraft): RequestLeaveForInput => ({ ...toRequestInput(draft), userId: draft.userId });
