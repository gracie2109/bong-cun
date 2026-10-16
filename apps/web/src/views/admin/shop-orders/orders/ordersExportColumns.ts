import type { ExportColumn } from "@/lib/data-io/columns";
import type { AdminOrderRow } from "@bongcun/core/shop";

const STATUS_TEXT: Record<string, string> = {
  pending: "Chờ xác nhận",
  confirmed: "Đã xác nhận",
  packed: "Đã đóng gói",
  shipping: "Đang giao",
  completed: "Hoàn tất",
  cancelled: "Đã hủy",
  returned: "Hoàn trả",
};

/** Columns of the online order export: one row per order. */
export const ordersExportColumns = (): ExportColumn<AdminOrderRow>[] => [
  { header: "Mã đơn", value: (row) => row.code, width: 18 },
  { header: "Ngày đặt", value: (row) => row.placedAt, kind: "datetime", width: 18 },
  { header: "Người nhận", value: (row) => row.receiverName, width: 24 },
  { header: "Số điện thoại", value: (row) => row.receiverPhone },
  { header: "Hình thức", value: (row) => (row.deliveryMethod === "pickup" ? "Nhận tại cửa hàng" : "Giao hàng"), width: 18 },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] ?? row.status },
  { header: "Số dòng hàng", value: (row) => row.lineCount, kind: "number" },
  { header: "Tổng tiền", value: (row) => row.total, kind: "money", sum: true },
  { header: "Mã vận đơn", value: (row) => row.trackingCode, width: 20 },
];
