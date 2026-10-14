import type { ImportRowResult } from "@/lib/data-io/types";

/** A conversion unit row as the import function reads it. */
export type ImportUnit = {
  name: string;
  factor: number | null;
  barcode: string;
  price: number | null;
  for_sale: boolean;
  for_purchase: boolean;
};

/** One variant row sent to `import_products`. `row` is the line number in the sheet. */
export type ImportRow = {
  row: string;
  group: string;
  category: string;
  brand: string;
  description: string;
  images: string[];
  attrs: { name: string; value: string }[];
  sku: string;
  barcode: string;
  unit: string;
  price: number | null;
  track_stock: boolean;
  is_active: boolean;
  units: ImportUnit[];
};

/** What `import_products` answers for one batch (the shared screens read it as an `ImportReport`). */
export type ProductImportReport = {
  ok: boolean;
  created_groups: number;
  updated_groups: number;
  created_variants: number;
  updated_variants: number;
  new_categories: string[];
  new_brands: string[];
  rows: ImportRowResult[];
};
