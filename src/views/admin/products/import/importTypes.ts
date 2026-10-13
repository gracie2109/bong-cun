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

/** What the import function says about one row. */
export type ImportRowResult = {
  row: string;
  action: "create" | "update" | "skip";
  errors: string[];
};

export type ImportReport = {
  ok: boolean;
  created_groups: number;
  updated_groups: number;
  created_variants: number;
  updated_variants: number;
  new_categories: string[];
  new_brands: string[];
  rows: ImportRowResult[];
};

/** The rows read from a file, with the problems found before anything is sent. */
export type ParsedFile = {
  rows: ImportRow[];
  /** Row number -> notes. */
  problems: Record<string, string[]>;
};
