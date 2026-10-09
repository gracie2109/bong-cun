import { computed, ref, watch } from "vue";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { fold, methodsOf, type Method } from "../rbac";
import { FILTER_ALL } from "@/lib/listing";

export const UNGROUPED = "__ungrouped";

/** Search, module/method/unused filters and client-side paging over the permission list. */
export const usePermissionsFilter = (
  permissions: () => readonly Permission[],
  rolesUsing: (permissionId: string) => Role[]
) => {
  const search = ref("");
  const moduleFilter = ref(FILTER_ALL);
  const methodFilter = ref(FILTER_ALL);
  const onlyUnused = ref(false);
  const page = ref(1);
  const pageSizeValue = ref("10");

  const filtered = computed(() => {
    const text = fold(search.value);
    return permissions().filter((permission) => {
      const module = permission.module?.trim() || null;
      if (moduleFilter.value === UNGROUPED && module) return false;
      if (moduleFilter.value !== FILTER_ALL && moduleFilter.value !== UNGROUPED && module !== moduleFilter.value) return false;
      if (methodFilter.value !== FILTER_ALL && !methodsOf(permission).includes(methodFilter.value as Method)) return false;
      if (onlyUnused.value && rolesUsing(permission.id).length > 0) return false;
      if (!text) return true;
      return fold(`${permission.name} ${permission.description ?? ""} ${module ?? ""}`).includes(text);
    });
  });

  const pageSize = computed({
    get: () => Number(pageSizeValue.value),
    set: (size: number) => {
      pageSizeValue.value = String(size);
    },
  });
  const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)));
  const pageItems = computed(() => filtered.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value));

  watch([search, moduleFilter, methodFilter, onlyUnused, pageSizeValue], () => {
    page.value = 1;
  });
  watch(pageCount, (count) => {
    if (page.value > count) page.value = count;
  });

  const resetFilters = () => {
    search.value = "";
    moduleFilter.value = FILTER_ALL;
    methodFilter.value = FILTER_ALL;
    onlyUnused.value = false;
  };

  return {
    search,
    moduleFilter,
    methodFilter,
    onlyUnused,
    page,
    pageSize,
    filtered,
    pageCount,
    pageItems,
    resetFilters,
  };
};
