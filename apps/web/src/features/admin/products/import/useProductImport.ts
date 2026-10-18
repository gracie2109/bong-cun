import { useTableImport } from "@/composables/useTableImport";
import type { ImportReport } from "@bongcun/core/data-io";
import { useImportProducts } from "@/features/admin/products/queries/productImport";
import type { ImportRow, ProductImportReport } from "@bongcun/core/data-io";
import { parseProductSheets } from "./parseProductSheets";
import { createImageRehoster } from "./rehostImages";

/** The shared report shape, with the product-only figures kept in `extra`. */
export const toImportReport = (report: ProductImportReport): ImportReport => ({
  ok: report.ok,
  created: report.created_variants,
  updated: report.updated_variants,
  rows: report.rows,
  extra: {
    created_groups: report.created_groups,
    updated_groups: report.updated_groups,
    new_categories: report.new_categories,
    new_brands: report.new_brands,
  },
});

const groupKey = (row: ImportRow) => row.group.trim().toLowerCase();

/** The product import: the shared flow with the product file reader and `import_products`. */
export const useProductImport = () => {
  const mutation = useImportProducts();
  const rehoster = createImageRehoster();
  return useTableImport<ImportRow>({
    parse: parseProductSheets,
    rowNumber: (row) => row.row,
    // the rows of one group are saved as a whole, so they travel in the same call
    batchKey: groupKey,
    fileKeys: ["file", "unit-sheet"],
    errorFileBase: "loi-nhap-san-pham",
    send: async (rows, dryRun, fileName) => {
      // Pictures on other sites are copied into our own storage when the rows are really saved.
      const ready = dryRun ? rows : await rehoster.apply(rows);
      const result = toImportReport(await mutation.mutateAsync({ rows: ready, dryRun, fileName }));
      if (!dryRun) rehoster.reportFailures();
      return result;
    },
  });
};
