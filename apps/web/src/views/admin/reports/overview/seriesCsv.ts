import type { CsvColumn } from "@/lib/csv";
import type { SeriesPoint } from "@/repositories/reports";

/** Columns of the revenue-by-day export; `t` turns an i18n key into the header text. */
export const seriesCsvColumns = (t: (key: string) => string): CsvColumn<SeriesPoint>[] => [
  { header: t("reports.cols.date"), value: (row) => row.bucket, kind: "date" },
  { header: t("reports.cols.invoices"), value: (row) => row.invoiceCount, kind: "number", sum: true },
  { header: t("reports.cols.gross"), value: (row) => row.gross, kind: "money", sum: true },
  { header: t("reports.cols.discount"), value: (row) => row.discount, kind: "money", sum: true },
  { header: t("reports.cols.refunds"), value: (row) => row.refunds, kind: "money", sum: true },
  { header: t("reports.cols.netRevenue"), value: (row) => row.netRevenue, kind: "money", sum: true },
  { header: t("reports.cols.shop"), value: (row) => row.shop, kind: "money", sum: true },
  { header: t("reports.cols.spa"), value: (row) => row.spa, kind: "money", sum: true },
  { header: t("reports.cols.boarding"), value: (row) => row.boarding, kind: "money", sum: true },
  { header: t("reports.cols.medical"), value: (row) => row.medical, kind: "money", sum: true },
  { header: t("reports.cols.cash"), value: (row) => row.cash, kind: "money", sum: true },
  { header: t("reports.cols.transfer"), value: (row) => row.transfer, kind: "money", sum: true },
  { header: t("reports.cols.card"), value: (row) => row.card, kind: "money", sum: true },
];
