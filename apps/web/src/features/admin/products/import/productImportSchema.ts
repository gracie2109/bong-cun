import type { ImportColumn } from "@/lib/data-io/importSchema";
import { MAX_ATTRIBUTES } from "./importTemplate";

const attributeColumns = (): ImportColumn[] =>
  Array.from({ length: MAX_ATTRIBUTES }, (_, i) => [
    { key: `attr_name_${i + 1}`, header: `Thuộc tính ${i + 1}` },
    { key: `attr_value_${i + 1}`, header: `Giá trị ${i + 1}` },
  ]).flat();

/** Columns of the product sheet (the headers are those of the template; order in the file does not matter). */
export const PRODUCT_COLUMNS: ImportColumn[] = [
  { key: "group", header: "Nhóm sản phẩm", aliases: ["Tên sản phẩm", "Nhóm"] },
  { key: "category", header: "Danh mục" },
  { key: "brand", header: "Thương hiệu" },
  { key: "description", header: "Mô tả" },
  { key: "images", header: "Ảnh (cách nhau bằng |)", aliases: ["Ảnh", "Hình ảnh"] },
  ...attributeColumns(),
  { key: "sku", header: "SKU", aliases: ["Mã SKU"] },
  { key: "barcode", header: "Mã vạch" },
  { key: "unit", header: "Đơn vị" },
  { key: "price", header: "Giá", kind: "number" },
  { key: "track_stock", header: "Theo dõi kho", kind: "flag", defaultFlag: true },
  { key: "is_active", header: "Đang bán", kind: "flag", defaultFlag: true },
];

/** Columns of the optional unit sheet, joined to the product sheet by SKU. */
export const UNIT_COLUMNS: ImportColumn[] = [
  { key: "sku", header: "SKU" },
  { key: "name", header: "Tên đơn vị" },
  { key: "factor", header: "Hệ số", kind: "number" },
  { key: "barcode", header: "Mã vạch" },
  { key: "price", header: "Giá", kind: "number" },
  { key: "for_sale", header: "Bán", kind: "flag", defaultFlag: true },
  { key: "for_purchase", header: "Nhập", kind: "flag", defaultFlag: false },
];
