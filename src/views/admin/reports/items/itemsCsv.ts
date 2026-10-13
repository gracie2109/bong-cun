import type { CsvColumn } from "@/lib/csv";
import type { TopItem } from "@/repositories/reports";

/** Columns of the top-items export; `t` turns an i18n key into the header text. */
export const itemsCsvColumns = (t: (key: string) => string): CsvColumn<TopItem>[] => [
  { header: t("reports.cols.name"), value: (row) => row.name },
  { header: t("reports.cols.sku"), value: (row) => row.sku },
  { header: t("reports.cols.type"), value: (row) => t(`reports.itemType.${row.itemType}`) },
  { header: t("reports.cols.qtySold"), value: (row) => row.qtySold },
  { header: t("reports.cols.qtyReturned"), value: (row) => row.qtyReturned },
  { header: t("reports.cols.itemRevenue"), value: (row) => row.netRevenue },
  { header: t("reports.cols.refunds"), value: (row) => row.refunds },
  { header: t("reports.cols.share"), value: (row) => row.share },
  { header: t("reports.cols.cost"), value: (row) => row.cost },
  { header: t("reports.cols.profit"), value: (row) => row.grossProfit },
];
