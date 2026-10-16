import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";

const TOP_MODULE_CHIPS = 3;

export type StatCard = {
  label: string;
  value: string;
  unit: string;
  note: string;
  icon: string;
  tone: string;
  valueClass: string;
};

/** Modules, role usage and the summary cards derived from the permission list. */
export const usePermissionCatalog = (permissions: () => readonly Permission[], roles: () => readonly Role[]) => {
  const { t } = useI18n();

  const modules = computed(() =>
    [...new Set(permissions().map((item) => item.module?.trim()).filter((item): item is string => !!item))].sort()
  );

  const countByModule = computed(() => {
    const counts = new Map<string, number>();
    for (const permission of permissions()) {
      const key = permission.module?.trim() || t("rbac.ungrouped");
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    return [...counts.entries()].sort((a, b) => b[1] - a[1]);
  });

  const topModules = computed(() =>
    countByModule.value
      .map(([module]) => module)
      .filter((module) => modules.value.includes(module))
      .slice(0, TOP_MODULE_CHIPS)
  );

  /** Roles (superAdmin excluded, it holds everything implicitly) granting any method on the permission. */
  const rolesUsing = (permissionId: string): Role[] =>
    roles().filter(
      (role) => !role.isSystem && role.permissions.some((grant) => grant.id === permissionId && grant.method.length > 0)
    );

  const unusedCount = computed(() => permissions().filter((item) => rolesUsing(item.id).length === 0).length);

  const statCards = computed<StatCard[]>(() => {
    const total = permissions().length;
    const [topName, topCount] = countByModule.value[0] ?? ["—", 0];
    const used = total - unusedCount.value;
    const percent = (n: number) => (total ? Math.round((n / total) * 100) : 0);
    return [
      {
        label: t("rbac.permissions.stats.total"),
        value: String(total),
        unit: t("rbac.permissions.stats.totalUnit", { n: countByModule.value.length }),
        note: t("rbac.permissions.stats.totalNote"),
        icon: "lucide:key-round",
        tone: "bg-primary/10 text-primary",
        valueClass: "",
      },
      {
        label: t("rbac.permissions.stats.topModule"),
        value: String(topCount),
        unit: topName,
        note: t("rbac.permissions.stats.topModuleNote", { n: percent(topCount) }),
        icon: "lucide:layers",
        tone: "bg-sky-50 text-sky-600",
        valueClass: "",
      },
      {
        label: t("rbac.permissions.stats.unused"),
        value: String(unusedCount.value).padStart(2, "0"),
        unit: t("rbac.permissions.stats.unusedUnit"),
        note: t("rbac.permissions.stats.unusedNote"),
        icon: "lucide:shield-alert",
        tone: "bg-amber-50 text-amber-600",
        valueClass: unusedCount.value > 0 ? "text-amber-600" : "",
      },
      {
        label: t("rbac.permissions.stats.coverage"),
        value: `${used}/${total}`,
        unit: `${percent(used)}%`,
        note: t("rbac.permissions.stats.coverageNote"),
        icon: "lucide:shield-check",
        tone: "bg-emerald-50 text-emerald-600",
        valueClass: "",
      },
    ];
  });

  return { modules, topModules, rolesUsing, unusedCount, statCards };
};
