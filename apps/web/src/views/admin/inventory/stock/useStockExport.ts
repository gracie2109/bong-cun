import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { getStockSummary, type StockFilter } from "@/repositories/inventory";
import { stockCountSheetColumns, stockExportColumns } from "./stockExportColumns";

/** Export of the stock list under its filter; the PDF is a count sheet to fill in by hand. */
export const useStockExport = (filter: Ref<StockFilter | null>, branchName: () => string | undefined) =>
  useTableExport({
    name: "Tồn kho",
    permission: "inventory",
    columns: stockExportColumns,
    printColumns: stockCountSheetColumns,
    enabled: () => !!filter.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!filter.value) return Promise.resolve({ rows: [], total: 0 });
      return getStockSummary(supabaseClient(), { pageIndex, pageSize }, filter.value);
    },
    meta: () => [branchName() ? `Cơ sở: ${branchName()}` : "", filter.value?.search ? `Tìm: ${filter.value.search}` : ""].filter(Boolean),
  });
