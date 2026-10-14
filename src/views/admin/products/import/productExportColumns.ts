import type { ExportColumn } from "@/lib/data-io/columns";
import type { ExportRow } from "./exportSheets";
import { IMAGE_SEPARATOR, MAX_ATTRIBUTES, PRODUCT_HEADERS } from "./importTemplate";

const attribute = (row: ExportRow, index: number, field: "name" | "value") => row.attrs[index]?.[field] ?? "";

/** CSV columns: the product sheet of the Excel export, with the template headers, so the file imports back. */
export const productCsvColumns = (): ExportColumn<ExportRow>[] => {
  const attributeCells = Array.from({ length: MAX_ATTRIBUTES }, (_, i) => [
    (row: ExportRow) => attribute(row, i, "name"),
    (row: ExportRow) => attribute(row, i, "value"),
  ]).flat();
  const values: ExportColumn<ExportRow>["value"][] = [
    (row) => row.group,
    (row) => row.category,
    (row) => row.brand,
    (row) => row.description,
    (row) => row.images.join(IMAGE_SEPARATOR),
    ...attributeCells,
    (row) => row.sku,
    (row) => row.barcode,
    (row) => row.unit,
    (row) => row.price,
    (row) => row.track_stock,
    (row) => row.is_active,
  ];
  const kinds: Record<number, ExportColumn<ExportRow>["kind"]> = { [values.length - 3]: "money", [values.length - 2]: "flag", [values.length - 1]: "flag" };
  return values.map((value, index) => ({ header: PRODUCT_HEADERS[index], value, kind: kinds[index] }));
};

/** The printed price list. */
export const productPriceListColumns = (): ExportColumn<ExportRow>[] => [
  { header: "Sản phẩm", value: (row) => row.group },
  { header: "SKU", value: (row) => row.sku },
  { header: "Danh mục", value: (row) => row.category },
  { header: "Đơn vị", value: (row) => row.unit },
  { header: "Giá", value: (row) => row.price, kind: "money" },
];
