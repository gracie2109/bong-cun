import { computed, ref } from "vue";
import { useImportProducts } from "@/queries/productImport";
import { batchByGroup, emptyReport, mergeReports } from "./batches";
import { PRODUCT_SHEET, UNIT_SHEET } from "./importTemplate";
import type { ImportReport, ImportRow, ParsedFile } from "./importTypes";
import { parseSheets } from "./parseRows";

export type ImportPhase = "idle" | "reading" | "checking" | "checked" | "importing" | "done";

/** One line of the preview: a file row with what the check said about it. */
export type PreviewRow = { row: ImportRow; action: "create" | "update" | "skip"; errors: string[] };

/**
 * The import flow: read the file, check it with a dry run (nothing is saved), and import it only
 * when no row has an error. Rows go to the database a few hundred at a time.
 */
export const useProductImport = () => {
  const mutation = useImportProducts();
  const phase = ref<ImportPhase>("idle");
  const fileName = ref("");
  const parsed = ref<ParsedFile | null>(null);
  const report = ref<ImportReport | null>(null);
  const progress = ref({ done: 0, total: 0 });
  const readError = ref("");

  const rows = computed(() => parsed.value?.rows ?? []);
  const fileNotes = computed(() => {
    const problems = parsed.value?.problems ?? {};
    return ["file", "unit-sheet"].flatMap((key) => problems[key] ?? []);
  });

  const preview = computed<PreviewRow[]>(() => {
    const results = new Map((report.value?.rows ?? []).map((item) => [item.row, item]));
    const problems = parsed.value?.problems ?? {};
    return rows.value.map((row) => {
      const result = results.get(row.row);
      const errors = [...(problems[row.row] ?? []), ...(result?.errors ?? [])];
      return { row, action: errors.length > 0 ? "skip" : (result?.action ?? "skip"), errors };
    });
  });
  const errorCount = computed(() => preview.value.filter((item) => item.errors.length > 0).length);
  const canImport = computed(
    () => phase.value === "checked" && errorCount.value === 0 && fileNotes.value.length === 0 && rows.value.length > 0
  );

  // Sends the rows in batches; every batch answers before the next goes out.
  const run = async (dryRun: boolean): Promise<ImportReport> => {
    const batches = batchByGroup(rows.value);
    progress.value = { done: 0, total: rows.value.length };
    let total = emptyReport();
    for (const batch of batches) {
      const part = await mutation.mutateAsync({ rows: batch, dryRun, fileName: fileName.value });
      total = mergeReports(total, part);
      progress.value = { done: progress.value.done + batch.length, total: rows.value.length };
    }
    return total;
  };

  const reset = () => {
    phase.value = "idle";
    fileName.value = "";
    parsed.value = null;
    report.value = null;
    readError.value = "";
    progress.value = { done: 0, total: 0 };
  };

  const loadFile = async (file: File) => {
    reset();
    fileName.value = file.name;
    phase.value = "reading";
    try {
      const { default: readXlsxFile } = await import("read-excel-file/browser");
      const sheets = await readXlsxFile(file);
      const products = sheets.find((sheet) => sheet.sheet === PRODUCT_SHEET) ?? sheets[0];
      const units = sheets.find((sheet) => sheet.sheet === UNIT_SHEET);
      if (!products) throw new Error("empty");
      parsed.value = parseSheets(products.data, units?.data);
    } catch {
      readError.value = "read";
      phase.value = "idle";
      return;
    }
    phase.value = "checking";
    try {
      report.value = await run(true);
      phase.value = "checked";
    } catch {
      // the mutation already showed the failure toast
      phase.value = "idle";
    }
  };

  const confirmImport = async () => {
    if (!canImport.value) return;
    phase.value = "importing";
    try {
      report.value = await run(false);
      phase.value = "done";
    } catch {
      phase.value = "checked";
    }
  };

  return { phase, fileName, report, progress, readError, rows, fileNotes, preview, errorCount, canImport, loadFile, confirmImport, reset };
};
