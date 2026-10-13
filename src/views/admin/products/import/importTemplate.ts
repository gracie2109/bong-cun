import type { SheetData } from "write-excel-file/browser";

/** Sheet names in the template; the unit sheet is optional. */
export const PRODUCT_SHEET = "San pham";
export const UNIT_SHEET = "Don vi";

export const MAX_ATTRIBUTES = 3;
export const MAX_FILE_ROWS = 2000;
/** Rows sent to the database in one call. */
export const BATCH_SIZE = 200;
export const IMAGE_SEPARATOR = "|";

/** Header texts of the product sheet, in column order. The attribute pairs repeat. */
export const PRODUCT_HEADERS = [
  "Nhóm sản phẩm",
  "Danh mục",
  "Thương hiệu",
  "Mô tả",
  "Ảnh (cách nhau bằng |)",
  "Thuộc tính 1",
  "Giá trị 1",
  "Thuộc tính 2",
  "Giá trị 2",
  "Thuộc tính 3",
  "Giá trị 3",
  "SKU",
  "Mã vạch",
  "Đơn vị",
  "Giá",
  "Theo dõi kho",
  "Đang bán",
] as const;

export const UNIT_HEADERS = ["SKU", "Tên đơn vị", "Hệ số", "Mã vạch", "Giá", "Bán", "Nhập"] as const;

export const YES = "Có";
export const NO = "Không";

const SAMPLE_PRODUCT_ROWS: SheetData = [
  ["Áo thun mèo", "Phụ kiện > Quần áo", "Bông Cún", "Áo cotton mềm", "", "Size", "S", "Màu", "Đỏ", "", "", "ATM-S-D", "", "cái", 120000, YES, YES],
  ["Áo thun mèo", "Phụ kiện > Quần áo", "Bông Cún", "", "", "Size", "M", "Màu", "Đỏ", "", "", "ATM-M-D", "", "cái", 130000, YES, YES],
  ["Hạt cho chó", "Thức ăn > Hạt", "Royal", "", "", "", "", "", "", "", "", "HAT-1KG", "8930000000011", "gói", 95000, YES, YES],
];

const SAMPLE_UNIT_ROWS: SheetData = [["HAT-1KG", "thùng", 12, "8930000000012", "", YES, YES]];

const header = (text: string) => ({ value: text, fontWeight: "bold" as const });

/** The sheets of the downloadable template: headers plus a few example rows. */
export const templateSheets = () => [
  { sheet: PRODUCT_SHEET, data: [PRODUCT_HEADERS.map(header), ...SAMPLE_PRODUCT_ROWS] },
  { sheet: UNIT_SHEET, data: [UNIT_HEADERS.map(header), ...SAMPLE_UNIT_ROWS] },
];

export const TEMPLATE_FILE_NAME = "mau-nhap-san-pham.xlsx";
export const EXPORT_FILE_NAME = "san-pham.xlsx";
