import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { exportProducts } from "@/repositories/productImport";
import { exportSheets } from "./exportSheets";
import type { ExportRow } from "@/types/dataImport";
import { TEMPLATE_FILE_NAME, templateSheets } from "./importTemplate";
import { productCsvColumns, productPriceListColumns } from "./productExportColumns";

// The Excel writer is loaded when a file is actually written, so the screen stays light.
const saveSheets = async (sheets: ReturnType<typeof templateSheets>, fileName: string) => {
  const { default: writeXlsxFile } = await import("write-excel-file/browser");
  await writeXlsxFile(sheets).toFile(fileName);
};

export const downloadTemplate = () => saveSheets(templateSheets(), TEMPLATE_FILE_NAME);

/** Export of every product variant: Excel in the import layout (two sheets), CSV of the product sheet, PDF price list. */
export const useProductsExport = () =>
  useTableExport<ExportRow>({
    name: "Sản phẩm",
    permission: "products",
    columns: productCsvColumns,
    printColumns: productPriceListColumns,
    fetchPage: (pageIndex, pageSize) => exportProducts(supabaseClient(), pageSize, (pageIndex - 1) * pageSize),
    // the import reads the two sheets back, so the Excel file keeps its own layout
    overrides: { xlsx: (rows, base) => saveSheets(exportSheets(rows), `${base}.xlsx`) },
  });
