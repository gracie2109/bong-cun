import type { CsvColumn } from "@/lib/csv";
import type { ShiftRecon } from "@/repositories/reports";

/** Columns of the shift reconciliation export; `t` turns an i18n key into the header text. */
export const shiftsCsvColumns = (t: (key: string) => string): CsvColumn<ShiftRecon>[] => [
  { header: t("reports.cols.shiftCode"), value: (row) => row.code },
  { header: t("reports.cols.branch"), value: (row) => row.branchCode },
  { header: t("reports.cols.cashier"), value: (row) => row.openedByName },
  { header: t("reports.cols.openedAt"), value: (row) => row.openedAt, kind: "datetime" },
  { header: t("reports.cols.closedAt"), value: (row) => row.closedAt, kind: "datetime" },
  { header: t("reports.cols.invoices"), value: (row) => row.invoiceCount, kind: "number", sum: true },
  { header: t("reports.cols.sales"), value: (row) => row.salesTotal, kind: "money", sum: true },
  { header: t("reports.cols.expectedCash"), value: (row) => row.expectedCash, kind: "money", sum: true },
  { header: t("reports.cols.countedCash"), value: (row) => row.countedCash, kind: "money", sum: true },
  { header: t("reports.cols.difference"), value: (row) => row.difference, kind: "money", sum: true },
];
