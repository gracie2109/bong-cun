import type { CsvColumn } from "@/lib/csv";
import type { StaffRevenue, StaffRole } from "@/repositories/reports";

/** Columns of the staff export for a role; `t` turns an i18n key into the header text. */
export const staffCsvColumns = (role: StaffRole, t: (key: string) => string): CsvColumn<StaffRevenue>[] => {
  const name = {
    header: t("reports.cols.staff"),
    value: (row: StaffRevenue) => row.name ?? t("reports.staff.unassigned"),
  };
  if (role === "spa") {
    return [
      name,
      { header: t("reports.cols.tickets"), value: (row) => row.ticketCount },
      { header: t("reports.cols.pets"), value: (row) => row.petCount },
      { header: t("reports.cols.serviceRevenue"), value: (row) => row.netSales },
    ];
  }
  return [
    name,
    { header: t("reports.cols.invoices"), value: (row) => row.invoiceCount },
    { header: t("reports.cols.netSales"), value: (row) => row.netSales },
    { header: t("reports.cols.refunds"), value: (row) => row.refunds },
    { header: t("reports.cols.cancelled"), value: (row) => row.cancelledCount },
    { header: t("reports.cols.avgTicket"), value: (row) => row.avgTicket },
  ];
};
