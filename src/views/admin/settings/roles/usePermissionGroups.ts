import { computed, ref } from "vue";
import type { Permission } from "@/repositories/permissions";
import { fold, groupByModule, type PermissionGroup } from "../rbac";

export type KeyedPermissionGroup = PermissionGroup & { key: string };

/** Permissions grouped by module, narrowed by a text filter, with each group's open state. */
export const usePermissionGroups = (permissions: () => readonly Permission[]) => {
  const filter = ref("");
  const openGroups = ref<Record<string, boolean>>({});

  const groups = computed<KeyedPermissionGroup[]>(() =>
    groupByModule(permissions()).map((group) => ({ ...group, key: group.module ?? "_" }))
  );

  const visibleGroups = computed(() => {
    const text = fold(filter.value);
    if (!text) return groups.value;
    return groups.value
      .map((group) => ({
        ...group,
        items: group.items.filter((item) =>
          fold(`${item.name} ${item.description ?? ""} ${group.module ?? ""}`).includes(text)
        ),
      }))
      .filter((group) => group.items.length > 0);
  });

  const setAllOpen = (open: boolean) => {
    openGroups.value = Object.fromEntries(groups.value.map((group) => [group.key, open]));
  };

  return { filter, openGroups, visibleGroups, setAllOpen };
};
