// Import functions of the shared file import (docs/nhap-xuat-du-lieu.md): the database checks a
// batch (dry run) or saves it, and answers per row.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { ImportReport } from "@/lib/data-io/types";
import type { Database } from "@/types/database.types";
import type { SupplierImportRow } from "@/views/admin/inventory/suppliers/import/suppliersImportRow";
import type { PetImportRow } from "@/views/admin/pets/import/petsImportRow";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

/** Customers and their pets, matched by the owner's phone number (and microchip). */
export const importPets = async (client: Client, rows: PetImportRow[], dryRun: boolean): Promise<ImportReport> =>
  unwrap(await client.rpc("import_pets", { p_rows: rows, p_dry_run: dryRun })) as unknown as ImportReport;

/** Suppliers, matched by tax code or name. */
export const importSuppliers = async (client: Client, rows: SupplierImportRow[], dryRun: boolean): Promise<ImportReport> =>
  unwrap(await client.rpc("import_suppliers", { p_rows: rows, p_dry_run: dryRun })) as unknown as ImportReport;

/** A product found by SKU for the stock receipt filled from a file. */
export type SkuProduct = {
  sku: string;
  productId: string;
  name: string;
  /** The base unit. */
  unit: string;
  trackStock: boolean;
  /** Conversion units in use; `forPurchase` tells which a receipt may be entered in. */
  units: { id: string; name: string; factor: number; forPurchase: boolean }[];
};

type SkuUnitJson = { id: string; name: string; factor: number | string; for_purchase: boolean };

export const findProductsBySku = async (client: Client, skus: string[]): Promise<SkuProduct[]> =>
  unwrap(await client.rpc("find_products_by_sku", { p_skus: skus })).map((row) => ({
    sku: row.sku,
    productId: row.product_id,
    name: row.name,
    unit: row.unit,
    trackStock: row.track_stock,
    units: ((row.units ?? []) as unknown as SkuUnitJson[]).map((unit) => ({
      id: unit.id,
      name: unit.name,
      factor: Number(unit.factor),
      forPurchase: unit.for_purchase,
    })),
  }));
