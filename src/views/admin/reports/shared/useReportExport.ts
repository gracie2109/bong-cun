import type { Ref } from "vue";
import { useI18n } from "vue-i18n";
import { useTableExport } from "@/composables/useTableExport";
import type { ExportColumn } from "@/lib/data-io/columns";
import { formatDate } from "@/lib/data-io/formatCell";
import type { ReportFilter } from "@/repositories/reports";

type ExportOptions<T, F extends ReportFilter> = {
  /** Tab name in the file name: bao-cao-<tab>-<from>-<to>.<ext> */
  tab: string;
  /** i18n key of the tab title, printed at the top of the PDF. */
  titleKey: string;
  filter: Ref<F | null>;
  /** Fetches up to EXPORT_LIMIT rows; `total` is how many exist. */
  fetchRows: (filter: F) => Promise<{ rows: T[]; total: number }>;
  columns: () => ExportColumn<T>[];
};

/** Exports a report tab as Excel, CSV or PDF; warns when more than EXPORT_LIMIT rows exist. */
export const useReportExport = <T, F extends ReportFilter = ReportFilter>(options: ExportOptions<T, F>) => {
  const { t } = useI18n();
  return useTableExport<T>({
    name: t(options.titleKey),
    permission: "reports",
    columns: options.columns,
    enabled: () => !!options.filter.value,
    fetchAll: () => {
      const filter = options.filter.value;
      if (!filter) return Promise.resolve({ rows: [], total: 0 });
      return options.fetchRows(filter);
    },
    fileBase: () => `bao-cao-${options.tab}-${options.filter.value?.from}-${options.filter.value?.to}`,
    meta: () => {
      const filter = options.filter.value;
      return filter ? [`${formatDate(filter.from)} - ${formatDate(filter.to)}`] : [];
    },
  });
};
