import type { ExportColumn } from "@/lib/data-io/columns";
import type { Supplier } from "@bongcun/supabase/inventory";

/** Columns of the supplier export; the headers match the supplier import template. */
export const suppliersExportColumns = (): ExportColumn<Supplier>[] => [
  { header: "Tên", value: (row) => row.name, width: 30 },
  { header: "Điện thoại", value: (row) => row.phone },
  { header: "Email", value: (row) => row.email, width: 26 },
  { header: "Địa chỉ", value: (row) => row.address, width: 36 },
  { header: "Mã số thuế", value: (row) => row.taxCode },
  { header: "Ghi chú", value: (row) => row.note, width: 30 },
  { header: "Đang dùng", value: (row) => row.isActive, kind: "flag" },
];
