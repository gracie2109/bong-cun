import type { ExportColumn } from "@/lib/data-io/columns";
import type { BoardingStay } from "@/types/boarding";

const STATUS_TEXT: Record<string, string> = {
  booked: "Đã đặt",
  checked_in: "Đang ở",
  checked_out: "Đã trả",
  paid: "Đã thanh toán",
  cancelled: "Đã hủy",
  no_show: "Không đến",
};

const join = (values: (string | null)[]): string => [...new Set(values.filter(Boolean))].join(", ");

/** Columns of the boarding stay export: one row per stay, pets and kennels joined in a cell. */
export const staysExportColumns = (): ExportColumn<BoardingStay>[] => [
  { header: "Mã lượt", value: (row) => row.code, width: 18 },
  { header: "Dự kiến vào", value: (row) => row.plannedInAt, kind: "datetime", width: 18 },
  { header: "Dự kiến ra", value: (row) => row.plannedOutAt, kind: "datetime", width: 18 },
  { header: "Khách hàng", value: (row) => row.customerName, width: 24 },
  { header: "Số điện thoại", value: (row) => row.customerPhone },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] ?? row.status },
  { header: "Thú cưng", value: (row) => join(row.pets.map((pet) => pet.petName)), width: 24 },
  { header: "Chuồng", value: (row) => join(row.pets.map((pet) => pet.kennelCode)), width: 18 },
  { header: "Tạm tính", value: (row) => row.estTotal, kind: "money" },
  { header: "Ghi chú", value: (row) => row.note, width: 30 },
];
