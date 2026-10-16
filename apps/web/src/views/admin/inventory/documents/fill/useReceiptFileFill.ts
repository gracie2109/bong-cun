import { useTableImport } from "@/composables/useTableImport";
import { supabaseClient } from "@/lib/supabase";
import { emptyReport } from "@/lib/data-io/types";
import { findProductsBySku, type SkuProduct } from "@/repositories/dataImports";
import { notifyFailure } from "@/queries/notify";
import type { EditLine } from "../documentLines";
import { parseReceiptFile } from "./parseReceiptFile";
import type { ReceiptFileRow } from "./receiptFileRow";
import { resolveReceiptRow, toRowResult } from "./resolveReceiptRows";

/**
 * Fills a receipt from a file. Nothing is saved here: the "import" step only looks the SKUs up and
 * hands the valid lines to `onLines`; the receipt stays a draft until the user saves or posts it.
 * Rows with an error are skipped and listed.
 */
export const useReceiptFileFill = (onLines: (lines: EditLine[]) => void) =>
  useTableImport<ReceiptFileRow>({
    parse: parseReceiptFile,
    rowNumber: (row) => row.row,
    errorFileBase: "loi-phieu-nhap-kho",
    allowPartial: true,
    send: async (rows, dryRun) => {
      let products: SkuProduct[];
      try {
        products = await findProductsBySku(supabaseClient(), [...new Set(rows.map((row) => row.sku))]);
      } catch (error) {
        notifyFailure("get", error);
        throw error;
      }
      const bySku = new Map(products.map((product) => [product.sku.trim().toLowerCase(), product]));
      const resolved = rows.map((row) => ({ row, ...resolveReceiptRow(row, bySku.get(row.sku.trim().toLowerCase())) }));
      if (!dryRun) onLines(resolved.flatMap((item) => (item.line ? [item.line] : [])));
      const report = emptyReport();
      report.rows = resolved.map((item) => toRowResult(item.row, item.error));
      report.created = resolved.filter((item) => item.line).length;
      report.ok = resolved.every((item) => item.line);
      return report;
    },
  });
