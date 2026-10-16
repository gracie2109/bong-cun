import type { PreviewColumn } from "@/composables/useTableImport";
import type { ImportRow } from "@bongcun/core/data-io";

/** Columns of the preview table of the product import. */
export const PREVIEW_COLUMNS: PreviewColumn<ImportRow>[] = [
  { label: "Nhóm sản phẩm", cell: (row) => row.group },
  { label: "SKU", cell: (row) => row.sku },
  { label: "Giá", cell: (row) => row.price ?? "", right: true },
];
