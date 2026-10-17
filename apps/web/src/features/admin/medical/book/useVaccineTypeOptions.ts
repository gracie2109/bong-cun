import { computed, type MaybeRef, unref } from "vue";
import { useVaccineTypes } from "@/features/admin/medical/queries/medical";

/** The active vaccine types (one page of 100 holds the whole catalog). */
export const useVaccineTypeOptions = (branchId?: MaybeRef<string | undefined>) => {
  const typesQuery = useVaccineTypes(
    computed(() => unref(branchId)),
    { pageIndex: 1, pageSize: 100 },
    { activeOnly: true }
  );
  return computed(() => typesQuery.data.value?.rows ?? []);
};
