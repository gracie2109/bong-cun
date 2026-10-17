import { computed, type Ref } from "vue";
import { useKennelTypes } from "@/features/admin/boarding/queries";

const OPTIONS_PAGE = { pageIndex: 1, pageSize: 100 };

/** Every active kennel type, for the type pickers of the kennel list and its dialog. */
export const useKennelTypeOptions = (branchId: Ref<string | undefined>) => {
  const query = useKennelTypes(branchId, OPTIONS_PAGE, { activeOnly: true });
  return computed(() => query.data.value?.rows ?? []);
};
