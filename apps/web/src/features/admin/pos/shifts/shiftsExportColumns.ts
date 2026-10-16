import type { ExportColumn } from "@/lib/data-io/columns";
import type { CashShift } from "@bongcun/supabase/pos";

const difference = (row: CashShift): number | null =>
  row.countedCash === null || row.expectedCash === null ? null : row.countedCash - row.expectedCash;

/** Columns of the cashier shift export. */
export const shiftsExportColumns = (): ExportColumn<CashShift>[] => [
  { header: "Mã ca", value: (row) => row.code, width: 18 },
  { header: "Trạng thái", value: (row) => (row.status === "open" ? "Đang mở" : "Đã đóng") },
  { header: "Thu ngân", value: (row) => row.openedByName, width: 22 },
  { header: "Mở lúc", value: (row) => row.openedAt, kind: "datetime", width: 18 },
  { header: "Đóng lúc", value: (row) => row.closedAt, kind: "datetime", width: 18 },
  { header: "Tiền đầu ca", value: (row) => row.openingCash, kind: "money", sum: true },
  { header: "Tiền dự kiến", value: (row) => row.expectedCash, kind: "money", sum: true },
  { header: "Tiền đếm", value: (row) => row.countedCash, kind: "money", sum: true },
  { header: "Chênh lệch", value: difference, kind: "money", sum: true },
  { header: "Ghi chú đóng ca", value: (row) => row.closeNote, width: 30 },
];
