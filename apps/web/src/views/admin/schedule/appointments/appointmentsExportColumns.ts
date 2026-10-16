import type { ExportColumn } from "@/lib/data-io/columns";
import type { Appointment } from "@bongcun/supabase/spa";

const STATUS_TEXT: Record<string, string> = {
  booked: "Đã đặt",
  checked_in: "Đã đến",
  in_progress: "Đang làm",
  done: "Xong",
  paid: "Đã thanh toán",
  cancelled: "Đã hủy",
  no_show: "Không đến",
};

const join = (values: (string | null)[]): string => [...new Set(values.filter(Boolean))].join(", ");

/** Columns of the spa appointment export: one row per appointment, tickets joined in a cell. */
export const appointmentsExportColumns = (): ExportColumn<Appointment>[] => [
  { header: "Mã lịch", value: (row) => row.code, width: 18 },
  { header: "Bắt đầu", value: (row) => row.startAt, kind: "datetime", width: 18 },
  { header: "Kết thúc", value: (row) => row.endAt, kind: "datetime", width: 18 },
  { header: "Khách hàng", value: (row) => row.customerName, width: 24 },
  { header: "Số điện thoại", value: (row) => row.customerPhone },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] ?? row.status },
  { header: "Dịch vụ", value: (row) => join(row.tickets.map((ticket) => ticket.name)), width: 34 },
  { header: "Thú cưng", value: (row) => join(row.tickets.map((ticket) => ticket.petName)), width: 22 },
  { header: "Nhân viên", value: (row) => join(row.tickets.map((ticket) => ticket.staffName)), width: 22 },
  { header: "Ghi chú", value: (row) => row.note, width: 30 },
];
