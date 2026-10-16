import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listStockDocuments, type StockDocumentFilter } from "@/repositories/inventory";
import { documentsExportColumns } from "./documentsExportColumns";

/** Export of the stock documents under the filter the list is showing (Excel and CSV only). */
export const useDocumentsExport = (filter: Ref<StockDocumentFilter | null>) =>
  useTableExport({
    name: "Phiếu kho",
    permission: "inventory",
    columns: documentsExportColumns,
    formats: ["xlsx", "csv"],
    enabled: () => !!filter.value,
    fetchPage: (pageIndex, pageSize) => {
      if (!filter.value) return Promise.resolve({ rows: [], total: 0 });
      return listStockDocuments(supabaseClient(), { pageIndex, pageSize }, filter.value);
    },
  });
