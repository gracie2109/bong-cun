import { ref, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { toast } from "vue-sonner";
import { downloadCsv, toCsv, type CsvColumn } from "@/lib/csv";
import { EXPORT_LIMIT, type ReportFilter } from "@/repositories/reports";

type ExportOptions<T> = {
  /** Tab name in the file name: bao-cao-<tab>-<from>-<to>.csv */
  tab: string;
  filter: Ref<ReportFilter | null>;
  /** Fetches up to EXPORT_LIMIT rows; `total` is how many exist. */
  fetchRows: (filter: ReportFilter) => Promise<{ rows: T[]; total: number }>;
  columns: () => CsvColumn<T>[];
};

/** Downloads a tab's rows as CSV; warns when more than EXPORT_LIMIT exist. */
export const useReportExport = <T>(options: ExportOptions<T>) => {
  const { t } = useI18n();
  const exporting = ref(false);

  const run = async () => {
    const filter = options.filter.value;
    if (!filter || exporting.value) return;
    exporting.value = true;
    try {
      const { rows, total } = await options.fetchRows(filter);
      downloadCsv(`bao-cao-${options.tab}-${filter.from}-${filter.to}.csv`, toCsv(rows, options.columns()));
      if (total > EXPORT_LIMIT) toast.warning(t("reports.export.truncated", { limit: EXPORT_LIMIT.toLocaleString("vi-VN") }));
    } catch (error) {
      console.error("Failed to export report", error);
      toast.error(t("reports.export.failed"));
    } finally {
      exporting.value = false;
    }
  };

  return { exporting, run };
};
