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
