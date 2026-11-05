import type { ExportColumn } from "@/lib/data-io/columns";
import type { TimesheetRow } from "@bongcun/core/attendance";

const hours = (minutes: number): number => Math.round((minutes / 60) * 100) / 100;

/** Columns of the timesheet export: one row per person, hours in decimal so a spreadsheet can add them up. */
export const timesheetExportColumns = (): ExportColumn<TimesheetRow>[] => [
  { header: "Nhân viên", value: (row) => row.name, width: 26 },
  { header: "Cơ sở", value: (row) => row.branchCodes, width: 14 },
  { header: "Ca xếp", value: (row) => row.shiftsScheduled, kind: "number", sum: true },
  { header: "Ca đã làm", value: (row) => row.shiftsWorked, kind: "number", sum: true },
  { header: "Giờ xếp", value: (row) => hours(row.scheduledMinutes), kind: "number", sum: true },
  { header: "Giờ làm", value: (row) => hours(row.workedMinutes), kind: "number", sum: true },
  { header: "Số lần đi trễ", value: (row) => row.lateCount, kind: "number", sum: true },
  { header: "Phút đi trễ", value: (row) => row.lateMinutes, kind: "number", sum: true },
  { header: "Số lần về sớm", value: (row) => row.earlyCount, kind: "number", sum: true },
  { header: "Phút về sớm", value: (row) => row.earlyMinutes, kind: "number", sum: true },
  { header: "Giờ tăng ca", value: (row) => hours(row.overtimeMinutes), kind: "number", sum: true },
  { header: "Ca vắng", value: (row) => row.absentCount, kind: "number", sum: true },
  { header: "Ca ngoài lịch", value: (row) => row.unscheduledCount, kind: "number", sum: true },
  { header: "Quên chấm ra", value: (row) => row.missingCheckoutCount, kind: "number", sum: true },
  { header: "Phép năm", value: (row) => row.leaveAnnual, kind: "number", sum: true },
  { header: "Nghỉ ốm", value: (row) => row.leaveSick, kind: "number", sum: true },
  { header: "Nghỉ không lương", value: (row) => row.leaveUnpaid, kind: "number", sum: true },
  { header: "Nghỉ khác", value: (row) => row.leaveOther, kind: "number", sum: true },
];
