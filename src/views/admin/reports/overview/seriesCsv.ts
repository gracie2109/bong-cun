import type { CsvColumn } from "@/lib/csv";
import type { SeriesPoint } from "@/repositories/reports";

/** Columns of the revenue-by-day export; `t` turns an i18n key into the header text. */
export const seriesCsvColumns = (t: (key: string) => string): CsvColumn<SeriesPoint>[] => [
  { header: t("reports.cols.date"), value: (row) => row.bucket },
  { header: t("reports.cols.invoices"), value: (row) => row.invoiceCount },
  { header: t("reports.cols.gross"), value: (row) => row.gross },
  { header: t("reports.cols.discount"), value: (row) => row.discount },
  { header: t("reports.cols.refunds"), value: (row) => row.refunds },
  { header: t("reports.cols.netRevenue"), value: (row) => row.netRevenue },
  { header: t("reports.cols.shop"), value: (row) => row.shop },
  { header: t("reports.cols.spa"), value: (row) => row.spa },
  { header: t("reports.cols.cash"), value: (row) => row.cash },
  { header: t("reports.cols.transfer"), value: (row) => row.transfer },
  { header: t("reports.cols.card"), value: (row) => row.card },
];
