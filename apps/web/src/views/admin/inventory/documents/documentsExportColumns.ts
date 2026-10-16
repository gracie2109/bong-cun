import type { ExportColumn } from "@/lib/data-io/columns";
import type { DocStatus, DocType, StockDocument } from "@bongcun/supabase/inventory";

const TYPE_TEXT: Record<DocType, string> = { receipt: "Phiếu nhập kho", writeoff: "Phiếu xuất hủy", count: "Phiếu kiểm kê" };
const STATUS_TEXT: Record<DocStatus, string> = { draft: "Nháp", posted: "Đã ghi sổ", cancelled: "Đã hủy" };

/** Columns of the stock document export: one row per document. */
export const documentsExportColumns = (): ExportColumn<StockDocument>[] => [
  { header: "Mã phiếu", value: (row) => row.code, width: 18 },
  { header: "Loại", value: (row) => TYPE_TEXT[row.docType], width: 16 },
  { header: "Trạng thái", value: (row) => STATUS_TEXT[row.status] },
  { header: "Nhà cung cấp", value: (row) => row.supplierName, width: 26 },
  { header: "Số chứng từ NCC", value: (row) => row.supplierRef, width: 18 },
  { header: "Tổng tiền", value: (row) => row.totalCost, kind: "money", sum: true },
  { header: "Ngày tạo", value: (row) => row.createdAt, kind: "datetime", width: 18 },
  { header: "Người tạo", value: (row) => row.createdByName, width: 20 },
  { header: "Ghi sổ lúc", value: (row) => row.postedAt, kind: "datetime", width: 18 },
  { header: "Người ghi sổ", value: (row) => row.postedByName, width: 20 },
  { header: "Ghi chú", value: (row) => row.note, width: 30 },
];
