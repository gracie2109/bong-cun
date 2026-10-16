import { computed, ref, shallowRef } from "vue";
import { toast } from "vue-sonner";
import { batchRows } from "@/lib/data-io/batches";
import { downloadErrorFile } from "@/lib/data-io/errorFile";
import { readTable, type SheetTable } from "@/lib/data-io/readTable";
import { emptyReport, mergeReports, type ImportReport, type ParsedImport } from "@/lib/data-io/types";

export type ImportPhase = "idle" | "reading" | "checking" | "checked" | "importing" | "done";

/** One line of the preview: a file row with what the check said about it. */
export type PreviewRow<R> = { row: R; rowNo: string; action: "create" | "update" | "skip"; errors: string[] };

/** One column of the preview table: its header and the text of a row. */
export type PreviewColumn<R> = { label: string; cell: (row: R) => string | number; right?: boolean };

export type TableImportOptions<R> = {
  /** Turns the sheets of the file into rows, listing the problems found before anything is sent. */
  parse: (sheets: SheetTable[]) => ParsedImport<R>;
  /** Checks (dryRun) or saves one batch of rows. Throws when the call fails (the caller shows the toast). */
  send: (rows: R[], dryRun: boolean, fileName: string) => Promise<ImportReport>;
  rowNumber: (row: R) => string;
  /** Rows of one key travel in the same batch. */
  batchKey?: (row: R) => string;
  /** Keys of `problems` that are about the whole file and block the import. */
  fileKeys?: string[];
  /** Base name of the "rows with errors" file. */
  errorFileBase?: string;
  /** Rows without an error may go ahead while others have errors (those are skipped and listed). */
  allowPartial?: boolean;
};

/**
 * The import flow shared by every screen: read the file, check it with a dry run (nothing is saved),
 * and import it only when no row has an error. Rows go to the database a few hundred at a time.
 */
export const useTableImport = <R>(options: TableImportOptions<R>) => {
  const phase = ref<ImportPhase>("idle");
  const fileName = ref("");
  const parsed = shallowRef<ParsedImport<R> | null>(null);
  const report = ref<ImportReport | null>(null);
  const progress = ref({ done: 0, total: 0 });
  const readError = ref(false);
  const fileKeys = options.fileKeys ?? ["file"];

  const rows = computed(() => parsed.value?.rows ?? []);
  const fileNotes = computed(() => fileKeys.flatMap((key) => parsed.value?.problems[key] ?? []));

  const preview = computed<PreviewRow<R>[]>(() => {
    const results = new Map((report.value?.rows ?? []).map((item) => [item.row, item]));
    const problems = parsed.value?.problems ?? {};
    return rows.value.map((row) => {
      const rowNo = options.rowNumber(row);
      const result = results.get(rowNo);
      const errors = [...(problems[rowNo] ?? []), ...(result?.errors ?? [])];
      return { row, rowNo, action: errors.length > 0 ? "skip" : (result?.action ?? "skip"), errors };
    });
  });
  const errorCount = computed(() => preview.value.filter((item) => item.errors.length > 0).length);
  const canImport = computed(
    () =>
      phase.value === "checked" &&
      fileNotes.value.length === 0 &&
      (options.allowPartial ? rows.value.length > errorCount.value : errorCount.value === 0 && rows.value.length > 0)
  );
  const busy = computed(() => ["reading", "checking", "importing"].includes(phase.value));

  const run = async (dryRun: boolean): Promise<ImportReport> => {
    // With partial imports, rows that already have a problem never go out.
    const problems = parsed.value?.problems ?? {};
    const sendable = options.allowPartial ? rows.value.filter((row) => !problems[options.rowNumber(row)]?.length) : rows.value;
    const batches = batchRows(sendable, undefined, options.batchKey);
    progress.value = { done: 0, total: sendable.length };
    let total = emptyReport();
    for (const batch of batches) {
      total = mergeReports(total, await options.send(batch, dryRun, fileName.value));
      progress.value = { done: progress.value.done + batch.length, total: sendable.length };
    }
    return total;
  };

  const reset = () => {
    phase.value = "idle";
    fileName.value = "";
    parsed.value = null;
    report.value = null;
    readError.value = false;
    progress.value = { done: 0, total: 0 };
  };

  const loadFile = async (file: File) => {
    reset();
    fileName.value = file.name;
    phase.value = "reading";
    try {
      parsed.value = options.parse(await readTable(file));
    } catch (error) {
      console.error("Failed to read the import file", error);
      readError.value = true;
      phase.value = "idle";
      return;
    }
    phase.value = "checking";
    try {
      report.value = await run(true);
      phase.value = "checked";
    } catch {
      // the caller's send() already showed the failure toast
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

  /** Saves the rows that have errors with a "Lỗi" column. */
  const downloadErrors = async () => {
    const source = parsed.value?.source;
    if (!source) return;
    const notes: Record<string, string[]> = {};
    for (const item of preview.value) if (item.errors.length > 0) notes[item.rowNo] = item.errors;
    try {
      await downloadErrorFile(source, notes, options.errorFileBase ?? "loi-nhap");
    } catch (error) {
      console.error("Failed to write the error file", error);
      toast.error("Không tạo được file lỗi.");
    }
  };

  return {
    phase, fileName, report, progress, readError, rows, fileNotes, preview, errorCount,
    canImport, busy, loadFile, confirmImport, reset, downloadErrors,
  };
};

export type TableImport<R> = ReturnType<typeof useTableImport<R>>;
