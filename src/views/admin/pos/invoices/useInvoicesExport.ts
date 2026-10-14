import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listInvoices, type InvoiceFilter } from "@/repositories/pos";
import { invoicesExportColumns } from "./invoicesExportColumns";

/** Export of the invoices under the filter the list is showing. */
export const useInvoicesExport = (filter: Ref<InvoiceFilter | null>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Hóa đơn",
    permission: "pos",
    columns: invoicesExportColumns,
    enabled: () => !!filter.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!filter.value) return Promise.resolve({ rows: [], total: 0 });
      return listInvoices(supabaseClient(), { pageIndex, pageSize }, filter.value);
    },
    meta: () => {
      const f = filter.value;
      return [branchName() ? `Cơ sở: ${branchName()}` : "", f?.search ? `Tìm: ${f.search}` : ""].filter(Boolean);
    },
  });
