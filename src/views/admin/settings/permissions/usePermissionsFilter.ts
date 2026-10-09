import { computed, ref, watch } from "vue";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { fold, methodsOf, type Method } from "../rbac";
import { FILTER_ALL } from "@/lib/listing";

export const UNGROUPED = "__ungrouped";
export const PAGE_SIZES = [10, 20, 50];

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
  const pageSizeValue = ref(String(PAGE_SIZES[0]));

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

  const pageSize = computed(() => Number(pageSizeValue.value));
  const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)));
  const pageItems = computed(() => filtered.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value));
  const pageFrom = computed(() => (filtered.value.length ? (page.value - 1) * pageSize.value + 1 : 0));
  const pageTo = computed(() => Math.min(page.value * pageSize.value, filtered.value.length));

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
    pageSizeValue,
    filtered,
    pageCount,
    pageItems,
    pageFrom,
    pageTo,
    resetFilters,
  };
};
