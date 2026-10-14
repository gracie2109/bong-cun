import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { toast } from "vue-sonner";
import { EXPORT_PDF_ROW_LIMIT, EXPORT_ROW_LIMIT, type ExportColumn, type ExportFormat } from "@/lib/data-io/columns";
import { writeCsv } from "@/lib/data-io/csvWrite";
import { fetchAllPages, type FetchedPage } from "@/lib/data-io/fetchAllPages";
import { exportFileBase } from "@/lib/data-io/fileName";
import { formatDateTime } from "@/lib/data-io/formatCell";
import { printTable } from "@/lib/data-io/printTable";
import { writeXlsx } from "@/lib/data-io/xlsxWrite";
import { downloadCsv } from "@/lib/csv";
import { useAuthStore } from "@/stores";

export const ALL_FORMATS: ExportFormat[] = ["pdf", "xlsx", "csv"];

export type TableExportOptions<T> = {
  /** Screen name: the PDF title, and the file name once lower-cased without accents. */
  name: string;
  /** Permission code whose EXPORT method shows the button. */
  permission: string;
  columns: () => ExportColumn<T>[];
  /** Lists that page (1-based page index): read page by page up to the limit. */
  fetchPage?: (pageIndex: number, pageSize: number) => Promise<FetchedPage<T>>;
  /** Lists that return everything in one call. */
  fetchAll?: () => Promise<FetchedPage<T>>;
  /** Replaces the default `<name>-<yyyymmdd-hhmm>` file name (without the extension). */
  fileBase?: () => string;
  /** Filter lines printed under the PDF title. */
  meta?: () => string[];
  /** False while the screen has nothing to export yet (e.g. a report filter that is not ready). */
  enabled?: () => boolean;
  /** Formats offered; all three when omitted. */
  formats?: ExportFormat[];
};

/** Exports the rows of a list as Excel, CSV or PDF, honouring the screen's filters and the row limits. */
export const useTableExport = <T>(options: TableExportOptions<T>) => {
  const { t } = useI18n();
  const auth = useAuthStore();
  const exporting = ref(false);
  const progress = ref<{ done: number; total: number } | null>(null);

  const canExport = computed(() => auth.can(options.permission, "EXPORT"));
  const disabled = computed(() => exporting.value || options.enabled?.() === false);

  const load = async (cap: number) => {
    if (options.fetchAll) {
      const { rows, total } = await options.fetchAll();
      return { rows: rows.slice(0, cap), total, truncated: total > cap };
    }
    if (!options.fetchPage) throw new Error("useTableExport needs fetchPage or fetchAll");
    return fetchAllPages(options.fetchPage, { cap, onProgress: (done, total) => (progress.value = { done, total }) });
  };

  const save = async (format: ExportFormat, rows: T[], total: number) => {
    const columns = options.columns();
    const base = options.fileBase?.() ?? exportFileBase(options.name);
    if (format === "csv") return downloadCsv(`${base}.csv`, writeCsv(rows, columns));
    if (format === "xlsx") return writeXlsx(rows, columns, `${base}.xlsx`, options.name);
    const who = auth.currentUser?.displayName;
    const stamp = t("dataIo.exportedAt", { time: formatDateTime(new Date()), who: who ?? "" });
    printTable({
      title: options.name,
      meta: [...(options.meta?.() ?? []), stamp],
      columns,
      rows,
      rowCountLabel: t("dataIo.rowCount", { count: total.toLocaleString("vi-VN") }),
    });
  };

  const run = async (format: ExportFormat) => {
    if (disabled.value) return;
    exporting.value = true;
    progress.value = null;
    try {
      const cap = format === "pdf" ? EXPORT_PDF_ROW_LIMIT : EXPORT_ROW_LIMIT;
      const { rows, total, truncated } = await load(cap);
      if (rows.length === 0) {
        toast.info(t("dataIo.empty"));
        return;
      }
      await save(format, rows, total);
      if (truncated) toast.warning(t("dataIo.truncated", { limit: cap.toLocaleString("vi-VN") }));
    } catch (error) {
      console.error("Failed to export", error);
      toast.error(t("dataIo.failed"));
    } finally {
      exporting.value = false;
      progress.value = null;
    }
  };

  return { canExport, exporting, disabled, progress, formats: options.formats ?? ALL_FORMATS, run };
};

export type TableExporter = ReturnType<typeof useTableExport>;
