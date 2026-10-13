import { ref } from "vue";
import { useExportProducts } from "@/queries/productImport";
import { exportSheets, type ExportRow } from "./exportSheets";
import { EXPORT_FILE_NAME, TEMPLATE_FILE_NAME, templateSheets } from "./importTemplate";

const EXPORT_PAGE = 500;

// The Excel writer is loaded when a file is actually written, so the screen stays light.
const saveSheets = async (sheets: ReturnType<typeof templateSheets>, fileName: string) => {
  const { default: writeXlsxFile } = await import("write-excel-file/browser");
  await writeXlsxFile(sheets).toFile(fileName);
};

export const downloadTemplate = () => saveSheets(templateSheets(), TEMPLATE_FILE_NAME);

export const downloadExport = (items: readonly ExportRow[]) => saveSheets(exportSheets(items), EXPORT_FILE_NAME);

/** Reads every product page by page and saves them as one Excel file. */
export const useExportAll = (save: (items: readonly ExportRow[]) => Promise<void>) => {
  const mutation = useExportProducts();
  const exporting = ref(false);

  const exportAll = async () => {
    exporting.value = true;
    try {
      const items: ExportRow[] = [];
      let total = Infinity;
      while (items.length < total) {
        const page = await mutation.mutateAsync({ limit: EXPORT_PAGE, offset: items.length });
        total = page.total;
        if (page.rows.length === 0) break;
        items.push(...page.rows);
      }
      await save(items);
    } catch {
      // the mutation already showed the failure toast
    } finally {
      exporting.value = false;
    }
  };

  return { exporting, exportAll };
};
