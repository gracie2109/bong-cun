import type { CsvColumn } from "@/lib/csv";
import type { StaffRevenue, StaffRole } from "@bongcun/supabase/reports";

/** Columns of the staff export for a role; `t` turns an i18n key into the header text. */
export const staffCsvColumns = (role: StaffRole, t: (key: string) => string): CsvColumn<StaffRevenue>[] => {
  const name = {
    header: t("reports.cols.staff"),
    value: (row: StaffRevenue) => row.name ?? t("reports.staff.unassigned"),
  };
  if (role === "spa") {
    return [
      name,
      { header: t("reports.cols.tickets"), value: (row) => row.ticketCount, kind: "number", sum: true },
      { header: t("reports.cols.pets"), value: (row) => row.petCount, kind: "number", sum: true },
      { header: t("reports.cols.serviceRevenue"), value: (row) => row.netSales, kind: "money", sum: true },
    ];
  }
  return [
    name,
    { header: t("reports.cols.invoices"), value: (row) => row.invoiceCount, kind: "number", sum: true },
    { header: t("reports.cols.netSales"), value: (row) => row.netSales, kind: "money", sum: true },
    { header: t("reports.cols.refunds"), value: (row) => row.refunds, kind: "money", sum: true },
    { header: t("reports.cols.cancelled"), value: (row) => row.cancelledCount, kind: "number", sum: true },
    { header: t("reports.cols.avgTicket"), value: (row) => row.avgTicket, kind: "money" },
  ];
};
