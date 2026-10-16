import type { ImportColumn } from "@/lib/data-io/importSchema";

/** Columns of the file that fills a stock receipt; order in the file does not matter. */
export const RECEIPT_COLUMNS: ImportColumn[] = [
  { key: "sku", header: "SKU", required: true },
  { key: "qty", header: "Số lượng", aliases: ["SL"], required: true, kind: "number" },
  { key: "unit", header: "Đơn vị" },
  { key: "cost", header: "Giá nhập", kind: "number" },
  { key: "lot_no", header: "Số lô", aliases: ["Lô"] },
  { key: "expiry", header: "Hạn dùng", aliases: ["HSD"], kind: "date" },
];

export const RECEIPT_TEMPLATE_BASE = "mau-phieu-nhap-kho";

/** Example rows of the template, in the order of RECEIPT_COLUMNS. */
export const RECEIPT_TEMPLATE_SAMPLES: (string | number)[][] = [
  ["HAT-1KG", 20, "gói", 85000, "L2610", "31/12/2027"],
  ["HAT-1KG", 2, "thùng", 1000000, "L2611", "30/06/2028"],
];
