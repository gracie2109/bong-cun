import type { Ref } from "vue";
import { useTableExport } from "@/composables/useTableExport";
import { supabaseClient } from "@/lib/supabase";
import { listUsers, type UserListFilter } from "@bongcun/supabase/users";
import { customersExportColumns } from "./customersExportColumns";

/** Export of the customer accounts under the filter the list is showing. */
export const useCustomersExport = (filter: Ref<UserListFilter>) =>
  useTableExport({
    name: "Khách hàng",
    permission: "users",
    columns: customersExportColumns,
    fetchPage: (pageIndex, pageSize) => listUsers(supabaseClient(), { pageIndex, pageSize }, filter.value),
    meta: () => (filter.value.search ? [`Tìm: ${filter.value.search}`] : []),
  });
