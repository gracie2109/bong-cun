import type { ExportColumn } from "@/lib/data-io/columns";
import type { Invoice, InvoiceStatus } from "@bongcun/supabase/pos";

const STATUS_TEXT: Record<InvoiceStatus, string> = { paid: "Đã thanh toán", unpaid: "Chờ thu", cancelled: "Đã hủy" };

/** Columns of the invoice export: one row per invoice (its lines are in the item report). */
export const invoicesExportColumns = (): ExportColumn<Invoice>[] => [
  { header: "Mã hóa đơn", value: (row) => row.code, width: 18 },
  { header: "Thời gian", value: (row) => row.createdAt, kind: "datetime", width: 18 },
  { header: "Kênh", value: (row) => (row.channel === "online" ? "Online" : "Tại quầy") },
  { header: "Khách hàng", value: (row) => row.customerName, width: 24 },
  { header: "Số điện thoại", value: (row) => row.customerPhone },
  { header: "Thu ngân", value: (row) => row.cashierName, width: 20 },
  { header: "Tạm tính", value: (row) => row.subtotal, kind: "money", sum: true },
  { header: "Giảm giá", value: (row) => row.discountAmount, kind: "money", sum: true },
  { header: "Tổng tiền", value: (row) => row.total, kind: "money", sum: true },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] },
  { header: "Ghi chú", value: (row) => row.note, width: 30 },
];
