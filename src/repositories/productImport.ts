// Excel import and export of products: the database checks and saves a group at a time.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { ExportRow } from "@/views/admin/products/import/exportSheets";
import type { ImportRow, ProductImportReport } from "@/views/admin/products/import/importTypes";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

/** With `dryRun` the database checks every row and rolls back, so nothing is saved. */
export const importProducts = async (
  client: Client,
  rows: ImportRow[],
  dryRun: boolean,
  fileName?: string
): Promise<ProductImportReport> => {
  const result = unwrap(
    await client.rpc("import_products", { p_rows: rows, p_dry_run: dryRun, p_file_name: fileName })
  );
  return result as unknown as ProductImportReport;
};

export type ExportPage = { total: number; rows: ExportRow[] };

export const exportProducts = async (client: Client, limit: number, offset: number): Promise<ExportPage> => {
  const result = unwrap(await client.rpc("export_products", { p_limit: limit, p_offset: offset }));
  return result as unknown as ExportPage;
};
