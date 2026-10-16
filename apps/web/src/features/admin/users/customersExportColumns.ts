import type { ExportColumn } from "@/lib/data-io/columns";
import type { IUser } from "@bongcun/core/users";

/** Columns of the web-account customer export. */
export const customersExportColumns = (): ExportColumn<IUser>[] => [
  { header: "Tên hiển thị", value: (row) => row.displayName, width: 24 },
  { header: "Họ và tên", value: (row) => row.fullName, width: 24 },
  { header: "Email", value: (row) => row.email, width: 30 },
  { header: "Số điện thoại", value: (row) => row.phoneNumber, width: 16 },
  { header: "Ngày tạo", value: (row) => (row.createdAt ? String(row.createdAt) : null), kind: "date" },
  { header: "Đang hoạt động", value: (row) => row.isActive, kind: "flag" },
];
