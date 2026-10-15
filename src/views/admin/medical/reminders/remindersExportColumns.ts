import type { ExportColumn } from "@/lib/data-io/columns";
import type { Reminder } from "@/types/vaccination";

/** Columns of the call list export: one row per pet and shot (or re-check). */
export const remindersExportColumns = (): ExportColumn<Reminder>[] => [
  { header: "Thú cưng", value: (row) => row.petName, width: 18 },
  { header: "Loài", value: (row) => row.speciesName, width: 12 },
  { header: "Khách hàng", value: (row) => row.customerName, width: 24 },
  { header: "Số điện thoại", value: (row) => row.customerPhone },
  { header: "Mũi tiêm / lý do", value: (row) => row.vaccineName, width: 28 },
  { header: "Ngày đến hạn", value: (row) => row.dueOn },
  { header: "Mũi gần nhất", value: (row) => row.lastGivenOn },
  { header: "Đã gọi lúc", value: (row) => row.remindedAt, kind: "datetime", width: 18 },
  { header: "Ghi chú", value: (row) => row.remindNote, width: 28 },
];
