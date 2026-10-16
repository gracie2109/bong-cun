import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import type { Permission } from "@/repositories/permissions";
import { fold, groupByModule, type PermissionGroup } from "../rbac";
import { FILTER_ALL } from "@/lib/listing";

export type MatrixGroup = PermissionGroup & { key: string };

/** Permissions grouped by module, narrowed by search and a module chip, with collapsible groups. */
export const useMatrixView = (permissions: () => readonly Permission[]) => {
  const { t } = useI18n();

  const search = ref("");
  const moduleFilter = ref(FILTER_ALL);
  const collapsed = ref<Record<string, boolean>>({});

  const groups = computed<MatrixGroup[]>(() =>
    groupByModule(permissions()).map((group) => ({ ...group, key: group.module ?? "_" }))
  );

  const moduleChips = computed(() => [
    { key: FILTER_ALL, label: t("petCare.common.all"), count: permissions().length },
    ...groups.value.map((group) => ({
      key: group.key,
      label: group.module ?? t("rbac.ungrouped"),
      count: group.items.length,
    })),
  ]);

  const visibleGroups = computed(() => {
    const text = fold(search.value);
    return groups.value
      .filter((group) => moduleFilter.value === FILTER_ALL || group.key === moduleFilter.value)
      .map((group) => ({
        ...group,
        items: text
          ? group.items.filter((item) => fold(`${item.name} ${item.description ?? ""}`).includes(text))
          : group.items,
      }))
      .filter((group) => group.items.length > 0);
  });
  const visibleCount = computed(() => visibleGroups.value.reduce((sum, group) => sum + group.items.length, 0));

  const allCollapsed = computed(
    () => groups.value.length > 0 && groups.value.every((group) => collapsed.value[group.key])
  );
  const setAllCollapsed = (value: boolean) => {
    collapsed.value = Object.fromEntries(groups.value.map((group) => [group.key, value]));
  };

  return { search, moduleFilter, collapsed, moduleChips, visibleGroups, visibleCount, allCollapsed, setAllCollapsed };
};
