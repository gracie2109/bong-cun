<template>
  <RbacLayout
    :eyebrow="$t('rbac.permissions.eyebrow')"
    :subtitle="$t('rbac.permissions.subtitle')"
  >
    <template #actions>
      <Button variant="outline" :disabled="!permissions.length" @click="exportCsv">
        <Download class="mr-2 size-4" />
        {{ $t("rbac.permissions.export") }}
      </Button>
      <Button v-if="canManage" @click="openForm(null)">
        <Plus class="mr-2 size-4" />
        {{ $t("rbac.permissions.add") }}
      </Button>
    </template>

    <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <div v-for="card in statCards" :key="card.label" class="rounded-xl border bg-white p-4">
        <div class="flex items-start justify-between gap-2">
          <p class="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">{{ card.label }}</p>
          <span class="flex size-8 items-center justify-center rounded-lg" :class="card.tone">
            <Icon :icon="card.icon" class="size-4" />
          </span>
        </div>
        <p class="mt-2 flex items-baseline gap-2">
          <span class="text-3xl font-bold" :class="card.valueClass">{{ card.value }}</span>
          <span class="text-sm text-muted-foreground">{{ card.unit }}</span>
        </p>
        <p class="mt-1 text-xs text-muted-foreground">{{ card.note }}</p>
      </div>
    </div>

    <div class="space-y-3 rounded-xl border bg-white p-4">
      <div class="flex flex-wrap items-center gap-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('rbac.permissions.searchPlaceholder')" />
        </div>
        <Select v-model="moduleFilter">
          <SelectTrigger class="w-52" :aria-label="$t('rbac.permissions.filterModule')">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("rbac.permissions.allModules", { n: modules.length }) }}</SelectItem>
            <SelectItem v-for="item in modules" :key="item" :value="item">{{ item }}</SelectItem>
            <SelectItem :value="UNGROUPED">{{ $t("rbac.ungrouped") }}</SelectItem>
          </SelectContent>
        </Select>
        <Select v-model="methodFilter">
          <SelectTrigger class="w-44" :aria-label="$t('rbac.permissions.filterMethod')">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("rbac.permissions.allMethods") }}</SelectItem>
            <SelectItem v-for="method in METHODS" :key="method" :value="method">{{ $t(`rbac.methods.${method}`) }}</SelectItem>
          </SelectContent>
        </Select>
        <Button variant="outline" size="icon" :aria-label="$t('rbac.permissions.resetFilters')" @click="resetFilters">
          <RotateCcw class="size-4" />
        </Button>
      </div>
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div class="flex flex-wrap items-center gap-2 text-xs">
          <span class="font-bold uppercase tracking-wider text-muted-foreground">{{ $t("rbac.permissions.quickFilters") }}</span>
          <button
            type="button"
            class="flex items-center gap-1.5 rounded-full border px-3 py-1 font-medium transition-colors"
            :class="onlyUnused ? 'border-amber-300 bg-amber-50 text-amber-700' : 'hover:bg-muted'"
            @click="onlyUnused = !onlyUnused"
          >
            <span class="size-1.5 rounded-full bg-amber-500" />
            {{ $t("rbac.permissions.unusedChip", { n: unusedCount }) }}
            <Check v-if="onlyUnused" class="size-3" />
          </button>
          <button
            v-for="item in topModules"
            :key="item"
            type="button"
            class="rounded-full border px-3 py-1 font-medium transition-colors"
            :class="moduleFilter === item ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
            @click="moduleFilter = moduleFilter === item ? ALL : item"
          >
            {{ item }}
          </button>
        </div>
        <p class="text-xs text-muted-foreground">
          {{ $t("rbac.permissions.resultCount") }}
          <b class="text-foreground">{{ $t("rbac.permissions.ratio", { n: filtered.length, total: permissions.length }) }}</b>
        </p>
      </div>
    </div>

    <div class="overflow-hidden rounded-xl border bg-white">
      <div class="table-scroll">
        <table class="w-full text-sm">
          <thead class="bg-muted/40">
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.desc") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.module") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.methods") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.roles") }}</th>
              <th class="px-4 py-3 text-right font-semibold"><span class="sr-only">{{ $t("rbac.permissions.col.actions") }}</span></th>
            </tr>
          </thead>
          <tbody>
            <template v-if="permissionsQuery.isPending.value">
              <tr v-for="i in 5" :key="i" class="border-t">
                <td colspan="6" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
              </tr>
            </template>
            <tr v-else-if="filtered.length === 0">
              <td colspan="6" class="px-4 py-10 text-center text-muted-foreground">{{ $t("rbac.permissions.empty") }}</td>
            </tr>
            <tr v-for="permission in pageItems" :key="permission.id" class="border-t align-top hover:bg-muted/20">
              <td class="px-4 py-4">
                <code class="rounded-md bg-muted px-2 py-1 font-mono text-xs font-semibold">{{ permission.name }}</code>
              </td>
              <td class="max-w-64 px-4 py-4">
                <p class="font-semibold leading-snug">{{ permission.description || permission.name }}</p>
              </td>
              <td class="px-4 py-4">
                <span class="inline-flex items-center gap-1.5 rounded-md bg-primary/10 px-2 py-1 text-xs font-medium text-primary">
                  <Icon :icon="moduleIcon(permission.module)" class="size-3.5" />
                  {{ permission.module || $t("rbac.ungrouped") }}
                </span>
              </td>
              <td class="px-4 py-4">
                <div class="flex max-w-56 flex-wrap gap-1">
                  <span
                    v-for="method in methodsOf(permission)"
                    :key="method"
                    class="flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium"
                    :class="method === 'DELETE' ? 'border-red-200 bg-red-50 text-red-700' : 'bg-white text-muted-foreground'"
                  >
                    <Icon :icon="METHOD_ICONS[method]" class="size-3" />
                    {{ $t(`rbac.methods.${method}`) }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-4">
                <div class="flex max-w-56 flex-wrap gap-1">
                  <router-link
                    v-for="role in rolesUsing(permission.id)"
                    :key="role.id"
                    :to="{ name: 'settings', query: { role: role.id } }"
                    class="rounded-md bg-muted px-2 py-0.5 text-[11px] font-medium hover:bg-primary/10 hover:text-primary"
                  >
                    {{ role.description || role.name }}
                  </router-link>
                  <span
                    v-if="rolesUsing(permission.id).length === 0"
                    class="rounded-md bg-amber-50 px-2 py-0.5 text-[11px] font-medium text-amber-700"
                  >
                    {{ $t("rbac.permissions.unused") }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-4 text-right">
                <DropdownMenu v-if="canManage">
                  <DropdownMenuTrigger as-child>
                    <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('rbac.permissions.col.actions')">
                      <EllipsisVertical class="size-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem @click="openForm(permission)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
                    <DropdownMenuItem class="text-red-600" @click="toDelete = permission">
                      {{ $t("rbac.roles.remove") }}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="filtered.length > 0"
        class="flex flex-wrap items-center justify-between gap-3 border-t px-4 py-3 text-sm text-muted-foreground"
      >
        <div class="flex items-center gap-3">
          <span>{{ $t("rbac.permissions.pageRange", { from: pageFrom, to: pageTo, total: filtered.length }) }}</span>
          <Select v-model="pageSizeValue">
            <SelectTrigger class="h-8 w-28" :aria-label="$t('rbac.permissions.perPage')"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="size in PAGE_SIZES" :key="size" :value="String(size)">
                {{ $t("rbac.permissions.perPageOption", { n: size }) }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="flex items-center gap-1">
          <Button variant="ghost" size="icon" class="size-8" :disabled="page === 1" @click="page--">
            <ChevronLeft class="size-4" />
          </Button>
          <Button
            v-for="n in pageCount"
            :key="n"
            :variant="n === page ? 'default' : 'ghost'"
            size="icon"
            class="size-8"
            @click="page = n"
          >
            {{ n }}
          </Button>
          <Button variant="ghost" size="icon" class="size-8" :disabled="page === pageCount" @click="page++">
            <ChevronRight class="size-4" />
          </Button>
        </div>
      </div>
    </div>

    <div class="flex items-start gap-3 rounded-xl border border-primary/20 bg-primary/5 p-4">
      <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-white text-primary">
        <ShieldCheck class="size-5" />
      </span>
      <div class="text-sm">
        <p class="font-semibold">{{ $t("rbac.permissions.policyTitle") }}</p>
        <p class="text-muted-foreground">{{ $t("rbac.permissions.policyBody") }}</p>
      </div>
    </div>

    <PermissionFormSheet v-model:open="formOpen" :permission="editing" :modules="modules" />

    <ConfirmDialog
      :open="!!toDelete"
      :title="$t('rbac.permissions.confirmDeleteTitle', { name: toDelete?.name ?? '' })"
      :desc="$t('rbac.permissions.confirmDeleteDesc')"
      :ok-btn="$t('petCare.common.confirm')"
      @cancel="toDelete = null"
      @open-change="toDelete = null"
      @handle-ok="remove"
    />
  </RbacLayout>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Icon } from "@iconify/vue";
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Download,
  EllipsisVertical,
  Plus,
  RotateCcw,
  Search,
  ShieldCheck,
} from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useCanManageRbac } from "@/composables/usePermission";
import { useDeletePermission, usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import type { Permission } from "@/repositories/permissions";
import RbacLayout from "../RbacLayout.vue";
import { CUSTOMER_ROLE, fold, METHOD_ICONS, METHODS, methodsOf, moduleIcon, roleMethods, type Method } from "../rbac";
import PermissionFormSheet from "./PermissionFormSheet.vue";

const ALL = "all";
const UNGROUPED = "__ungrouped";
const PAGE_SIZES = [10, 20, 50];

const { t } = useI18n();

const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const deletePermission = useDeletePermission();
const canManage = useCanManageRbac();

const search = ref("");
const moduleFilter = ref(ALL);
const methodFilter = ref(ALL);
const onlyUnused = ref(false);
const page = ref(1);
const pageSizeValue = ref(String(PAGE_SIZES[0]));
const formOpen = ref(false);
const editing = ref<Permission | null>(null);
const toDelete = ref<Permission | null>(null);

const modules = computed(() =>
  [...new Set(permissions.value.map((item) => item.module?.trim()).filter((item): item is string => !!item))].sort()
);

const countByModule = computed(() => {
  const counts = new Map<string, number>();
  for (const permission of permissions.value) {
    const key = permission.module?.trim() || t("rbac.ungrouped");
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
});
const topModules = computed(() =>
  countByModule.value
    .map(([module]) => module)
    .filter((module) => modules.value.includes(module))
    .slice(0, 3)
);

/** Roles (superAdmin excluded, it holds everything implicitly) granting any method on the permission. */
const rolesUsing = (permissionId: string) =>
  roles.value.filter(
    (role) => !role.isSystem && role.permissions.some((grant) => grant.id === permissionId && grant.method.length > 0)
  );

const unusedCount = computed(() => permissions.value.filter((item) => rolesUsing(item.id).length === 0).length);

const statCards = computed(() => {
  const total = permissions.value.length;
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

const filtered = computed(() => {
  const text = fold(search.value);
  return permissions.value.filter((permission) => {
    const module = permission.module?.trim() || null;
    if (moduleFilter.value === UNGROUPED && module) return false;
    if (moduleFilter.value !== ALL && moduleFilter.value !== UNGROUPED && module !== moduleFilter.value) return false;
    if (methodFilter.value !== ALL && !methodsOf(permission).includes(methodFilter.value as Method)) return false;
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
  moduleFilter.value = ALL;
  methodFilter.value = ALL;
  onlyUnused.value = false;
};

const csvCell = (value: string): string => `"${value.replace(/"/g, '""')}"`;

/** Downloads the filtered list as CSV; the BOM makes Excel read Vietnamese correctly. */
const exportCsv = () => {
  const header = [
    t("rbac.permissions.col.code"),
    t("rbac.permissions.col.desc"),
    t("rbac.permissions.col.module"),
    t("rbac.permissions.col.methods"),
    t("rbac.permissions.col.roles"),
  ];
  const rows = filtered.value.map((permission) => [
    permission.name,
    permission.description ?? "",
    permission.module ?? "",
    methodsOf(permission).map((method) => t(`rbac.methods.${method}`)).join(", "),
    roles.value
      .filter((role) => roleMethods(role, permission).length > 0 && role.name !== CUSTOMER_ROLE)
      .map((role) => role.description || role.name)
      .join(", "),
  ]);
  const csv = [header, ...rows].map((row) => row.map(csvCell).join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob(["﻿", csv], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = "permissions.csv";
  link.click();
  URL.revokeObjectURL(url);
};

const openForm = (permission: Permission | null) => {
  editing.value = permission;
  formOpen.value = true;
};

const remove = async () => {
  const target = toDelete.value;
  toDelete.value = null;
  if (!target) return;
  try {
    await deletePermission.mutateAsync(target.id);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
