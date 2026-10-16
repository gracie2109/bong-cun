import type { ImportColumn } from "@/lib/data-io/importSchema";

/** Columns of the supplier file (the same headers as the supplier export). */
export const SUPPLIER_COLUMNS: ImportColumn[] = [
  { key: "name", header: "Tên", aliases: ["Tên nhà cung cấp"], required: true },
  { key: "phone", header: "Điện thoại", aliases: ["Số điện thoại", "SĐT"] },
  { key: "email", header: "Email" },
  { key: "address", header: "Địa chỉ" },
  { key: "tax_code", header: "Mã số thuế", aliases: ["MST"] },
  { key: "note", header: "Ghi chú" },
  { key: "is_active", header: "Đang dùng", kind: "flag", emptyAsNull: true },
];

export const SUPPLIERS_TEMPLATE_BASE = "mau-nhap-nha-cung-cap";

/** Example rows of the template, in the order of SUPPLIER_COLUMNS. */
export const SUPPLIERS_TEMPLATE_SAMPLES: (string | number)[][] = [
  ["Công ty Thức ăn Royal", "0281234567", "sales@royal.example", "12 Nguyễn Huệ, Q1, TP.HCM", "0312345678", "Giao hàng thứ 3", "Có"],
  ["Cửa hàng phụ kiện Mèo Con", "0909000111", "", "", "", "", ""],
];
