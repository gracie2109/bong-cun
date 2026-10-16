import type { ExportColumn } from "@/lib/data-io/columns";
import type { StockRow } from "@/repositories/inventory";

/** Columns of the stock export (Excel and CSV). */
export const stockExportColumns = (): ExportColumn<StockRow>[] => [
  { header: "Sản phẩm", value: (row) => row.name, width: 36 },
  { header: "SKU", value: (row) => row.sku },
  { header: "Mã vạch", value: (row) => row.barcode },
  { header: "Đơn vị", value: (row) => row.unit },
  { header: "Tồn bán được", value: (row) => row.sellable, kind: "number", sum: true },
  { header: "Hết hạn", value: (row) => row.expired, kind: "number", sum: true },
  { header: "Sắp hết hạn", value: (row) => row.expiring, kind: "number", sum: true },
  { header: "Hạn gần nhất", value: (row) => row.nextExpiry, kind: "date" },
  { header: "Tồn tối thiểu", value: (row) => row.minQty, kind: "number" },
  { header: "Giá trị tồn", value: (row) => row.stockValue, kind: "money", sum: true },
];

/** The printed count sheet: book stock plus empty boxes for the counted quantity and a note. */
export const stockCountSheetColumns = (): ExportColumn<StockRow>[] => [
  { header: "Sản phẩm", value: (row) => row.name },
  { header: "SKU", value: (row) => row.sku },
  { header: "Đơn vị", value: (row) => row.unit },
  { header: "Hạn gần nhất", value: (row) => row.nextExpiry, kind: "date" },
  { header: "Tồn sổ sách", value: (row) => row.onHand, kind: "number" },
  { header: "Số đếm thực tế", value: () => "" },
  { header: "Ghi chú", value: () => "" },
];
