import type { SheetData } from "write-excel-file/browser";
import { IMAGE_SEPARATOR, MAX_ATTRIBUTES, NO, PRODUCT_HEADERS, PRODUCT_SHEET, UNIT_HEADERS, UNIT_SHEET, YES } from "./importTemplate";

/** One variant as `export_products` returns it. */
export type ExportRow = {
  group: string;
  category: string | null;
  brand: string | null;
  description: string | null;
  images: string[];
  attrs: { name: string; value: string }[];
  sku: string | null;
  barcode: string | null;
  unit: string;
  price: number;
  track_stock: boolean;
  is_active: boolean;
  units: { name: string; factor: number; barcode: string | null; price: number | null; for_sale: boolean; for_purchase: boolean }[];
};

const flag = (value: boolean) => (value ? YES : NO);
const header = (text: string) => ({ value: text, fontWeight: "bold" as const });

const productLine = (item: ExportRow) => {
  const attrCells = Array.from({ length: MAX_ATTRIBUTES }, (_, i) => [item.attrs[i]?.name ?? "", item.attrs[i]?.value ?? ""]).flat();
  return [
    item.group,
    item.category ?? "",
    item.brand ?? "",
    item.description ?? "",
    item.images.join(IMAGE_SEPARATOR),
    ...attrCells,
    item.sku ?? "",
    item.barcode ?? "",
    item.unit,
    Number(item.price),
    flag(item.track_stock),
    flag(item.is_active),
  ];
};

/** The sheets of an export, in the layout the import reads back. */
export const exportSheets = (items: readonly ExportRow[]) => {
  const unitLines: SheetData = items.flatMap((item) =>
    item.units.map((unit) => [
      item.sku ?? "",
      unit.name,
      Number(unit.factor),
      unit.barcode ?? "",
      unit.price == null ? "" : Number(unit.price),
      flag(unit.for_sale),
      flag(unit.for_purchase),
    ])
  );
  return [
    { sheet: PRODUCT_SHEET, data: [PRODUCT_HEADERS.map(header), ...items.map(productLine)] },
    { sheet: UNIT_SHEET, data: [UNIT_HEADERS.map(header), ...unitLines] },
  ];
};
