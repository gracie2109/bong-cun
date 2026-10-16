// Row shapes the admin data import/export screens exchange with the import_* / export_products functions.
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

/** One file row as `import_suppliers` reads it. An empty value means "keep what is saved". */
export type SupplierImportRow = {
  row: string;
  name: string;
  phone: string;
  email: string;
  address: string;
  tax_code: string;
  note: string;
  is_active: boolean | null;
};

/** One file row as `import_pets` reads it. An empty value means "keep what is saved". */
export type PetImportRow = {
  row: string;
  owner_phone: string;
  owner_name: string;
  owner_email: string;
  owner_note: string;
  pet_name: string;
  species: string;
  breed: string;
  sex: "male" | "female" | "unknown" | "";
  neutered: boolean | null;
  birth_date: string | null;
  microchip: string;
  allergies: string;
  behavior_notes: string;
};
