import type { CsvColumn } from "@/lib/csv";
import type { Adjustment } from "@/repositories/reports";

/** Columns of the returns-and-cancellations export; `t` turns an i18n key into the header text. */
export const adjustmentsCsvColumns = (t: (key: string) => string): CsvColumn<Adjustment>[] => [
  { header: t("reports.cols.kind"), value: (row) => t(`reports.adjustments.kinds.${row.kind}`) },
  { header: t("reports.cols.code"), value: (row) => row.code },
  { header: t("reports.cols.invoiceCode"), value: (row) => row.invoiceCode },
  { header: t("reports.cols.time"), value: (row) => row.at },
  { header: t("reports.cols.items"), value: (row) => row.itemSummary },
  { header: t("reports.cols.amount"), value: (row) => row.amount },
  { header: t("reports.cols.refundMethod"), value: (row) => (row.method ? t(`reports.method.${row.method}`) : "") },
  { header: t("reports.cols.reason"), value: (row) => row.reason },
  { header: t("reports.cols.by"), value: (row) => row.byName },
];
