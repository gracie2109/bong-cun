<template>
  <RbacLayout
    :eyebrow="$t('rbac.matrix.eyebrow')"
    :title="$t('rbac.matrix.title')"
    :subtitle="$t('rbac.matrix.subtitle')"
  >
    <template v-if="canManage" #actions>
      <Button variant="outline" as-child>
        <router-link :to="{ name: 'settings', query: { new: '1' } }">
          <Plus class="mr-2 size-4" />
          {{ $t("rbac.roles.add") }}
        </router-link>
      </Button>
      <Button :disabled="!editCount || saving" @click="saveMatrix">
        <Save class="mr-2 size-4" />
        {{ editCount ? $t("rbac.matrix.saveCount", { n: editCount }) : $t("rbac.matrix.save") }}
      </Button>
    </template>

    <div class="grid items-start gap-5" :class="detailRole ? 'xl:grid-cols-[minmax(0,1fr)_340px]' : ''">
      <div class="min-w-0 space-y-4">
        <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
          <div class="relative min-w-52 flex-1">
            <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input v-model="search" class="pl-9" :placeholder="$t('rbac.matrix.searchPlaceholder')" />
          </div>
          <label
            v-if="canManage"
            class="flex cursor-pointer items-center gap-2 rounded-lg border px-3 py-1.5"
            :class="quickEdit ? 'border-primary bg-primary/5' : ''"
          >
            <Checkbox v-model:checked="quickEdit" />
            <span class="leading-tight">
              <span class="block text-sm font-semibold">{{ $t("rbac.matrix.quickEdit") }}</span>
              <span class="block text-[11px] text-muted-foreground">{{ $t("rbac.matrix.quickEditHint") }}</span>
            </span>
          </label>
          <span class="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
            <span class="size-2 rounded-full bg-primary" />
            {{ $t("rbac.matrix.permissionCount", { n: permissions.length }) }}
          </span>
        </div>

        <div class="flex flex-wrap gap-2">
          <button
            v-for="chip in moduleChips"
            :key="chip.key"
            type="button"
            class="rounded-full border px-3 py-1.5 text-sm font-medium transition-colors"
            :class="moduleFilter === chip.key ? 'border-foreground bg-foreground text-background' : 'bg-white hover:bg-muted'"
            @click="moduleFilter = chip.key"
          >
            {{ chip.label }} ({{ chip.count }})
          </button>
        </div>

        <div class="overflow-hidden rounded-xl border bg-white">
          <div v-if="loading" class="space-y-2 p-4">
            <Skeleton v-for="i in 6" :key="i" class="h-10 w-full" />
          </div>
          <p v-else-if="permissions.length === 0" class="px-4 py-10 text-center text-sm text-muted-foreground">
            {{ $t("rbac.roles.noPermissions") }}
          </p>
          <div v-else class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b">
                  <th class="sticky left-0 z-10 min-w-64 bg-white px-4 py-3 text-left align-bottom">
                    <span class="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                      {{ $t("rbac.matrix.feature") }}
                    </span>
                    <button
                      type="button"
                      class="ml-3 text-[11px] font-semibold text-primary hover:underline"
                      @click="setAllCollapsed(!allCollapsed)"
                    >
                      {{ allCollapsed ? $t("rbac.roles.expandAll") : $t("rbac.roles.collapseAll") }}
                    </button>
                  </th>
                  <th
                    v-for="role in staffRoles"
                    :key="role.id"
                    class="min-w-32 px-3 py-3 text-center align-bottom"
                    :class="detailRole?.id === role.id ? 'bg-primary/5' : ''"
                  >
                    <button type="button" class="group flex w-full flex-col items-center gap-1" @click="detailId = role.id">
                      <span
                        class="flex size-8 items-center justify-center rounded-full"
                        :class="detailRole?.id === role.id ? 'bg-primary text-primary-foreground' : 'bg-primary/10 text-primary'"
                      >
                        <Crown v-if="role.name === SUPER_ADMIN_ROLE" class="size-4" />
                        <UserCog v-else class="size-4" />
                      </span>
                      <span class="font-semibold group-hover:text-primary">{{ role.description || role.name }}</span>
                      <span class="text-[10px] font-medium uppercase tracking-wide text-muted-foreground">
                        {{ $t("rbac.roles.staffCount", { n: role.staffCount }) }}
                      </span>
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody>
                <template v-for="group in visibleGroups" :key="group.key">
                  <tr class="border-t bg-primary/5">
                    <td :colspan="staffRoles.length + 1" class="px-4 py-2">
                      <button
                        type="button"
                        class="sticky left-4 flex items-center gap-2 text-sm font-semibold"
                        @click="collapsed[group.key] = !collapsed[group.key]"
                      >
                        <ChevronDown class="size-4 transition-transform" :class="collapsed[group.key] ? '-rotate-90' : ''" />
                        <Icon :icon="moduleIcon(group.module)" class="size-4 text-primary" />
                        {{ group.module ?? $t("rbac.ungrouped") }}
                        <span class="rounded-full bg-white px-2 py-0.5 text-[11px] font-medium text-muted-foreground">
                          {{ $t("rbac.matrix.featureCount", { n: group.items.length }) }}
                        </span>
                      </button>
                    </td>
                  </tr>
                  <template v-if="!collapsed[group.key]">
                    <tr v-for="permission in group.items" :key="permission.id" class="border-t hover:bg-muted/20">
                      <td class="sticky left-0 z-10 bg-white px-4 py-3">
                        <p class="font-medium leading-snug">{{ permission.description || permission.name }}</p>
                        <p class="font-mono text-[11px] text-muted-foreground">{{ permission.name }}</p>
                      </td>
                      <td
                        v-for="role in staffRoles"
                        :key="role.id"
                        class="px-3 py-3 text-center"
                        :class="detailRole?.id === role.id ? 'bg-primary/5' : ''"
                      >
                        <div class="flex flex-col items-center gap-1">
                          <Checkbox
                            :checked="cellState(role, permission)"
                            :disabled="!quickEdit || role.name === SUPER_ADMIN_ROLE"
                            :class="role.name === SUPER_ADMIN_ROLE ? 'border-muted-foreground/40 data-[state=checked]:bg-muted-foreground/40' : ''"
                            :aria-label="`${role.description || role.name}: ${permission.description || permission.name}`"
                            @update:checked="(value: boolean | 'indeterminate') => toggleCell(role, permission, value === true)"
                          />
                          <span
                            v-if="cellState(role, permission) === 'indeterminate'"
                            class="text-[10px] leading-tight text-muted-foreground"
                          >
                            {{ cellMethods(role, permission).map((method) => $t(`rbac.methods.${method}`)).join(", ") }}
                          </span>
                        </div>
                      </td>
                    </tr>
                  </template>
                </template>
                <tr v-if="visibleGroups.length === 0">
                  <td :colspan="staffRoles.length + 1" class="px-4 py-10 text-center text-muted-foreground">
                    {{ $t("rbac.roles.noMatch") }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="flex flex-wrap items-center gap-x-5 gap-y-2 border-t px-4 py-3 text-xs text-muted-foreground">
            <span class="flex items-center gap-1.5">
              <Checkbox :checked="true" disabled class="size-4 border-muted-foreground/40 data-[state=checked]:bg-muted-foreground/40" />
              {{ $t("rbac.matrix.legendSystem") }}
            </span>
            <span class="flex items-center gap-1.5">
              <Checkbox :checked="true" class="pointer-events-none size-4" tabindex="-1" />
              {{ $t("rbac.matrix.legendFull") }}
            </span>
            <span class="flex items-center gap-1.5">
              <Checkbox checked="indeterminate" class="pointer-events-none size-4" tabindex="-1" />
              {{ $t("rbac.matrix.legendPartial") }}
            </span>
            <span class="flex items-center gap-1.5">
              <Checkbox :checked="false" class="pointer-events-none size-4" tabindex="-1" />
              {{ $t("rbac.matrix.legendNone") }}
            </span>
            <span class="ml-auto">{{ $t("rbac.matrix.showing", { n: visibleCount, total: permissions.length }) }}</span>
          </div>
        </div>
      </div>

      <aside v-if="detailRole" class="space-y-4 rounded-xl border bg-white p-4 xl:sticky xl:top-4">
        <div class="flex items-center justify-between">
          <h3 class="flex items-center gap-2 font-semibold">
            <IdCard class="size-4 text-primary" />
            {{ $t("rbac.matrix.detail") }}
          </h3>
          <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('rbac.matrix.closeDetail')" @click="detailId = CLOSED">
            <X class="size-4" />
          </Button>
        </div>

        <div class="space-y-3 rounded-xl bg-muted/40 p-4">
          <div class="flex items-start gap-3">
            <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground">
              <Crown v-if="detailRole.name === SUPER_ADMIN_ROLE" class="size-5" />
              <UserCog v-else class="size-5" />
            </span>
            <div class="min-w-0">
              <p class="truncate text-lg font-bold">{{ detailRole.description || detailRole.name }}</p>
              <p class="font-mono text-[11px] uppercase text-muted-foreground">{{ $t("rbac.matrix.roleCode") }} {{ detailRole.name }}</p>
            </div>
          </div>
          <p v-if="detailRole.isSystem" class="text-xs text-muted-foreground">
            {{ detailRole.name === SUPER_ADMIN_ROLE ? $t("rbac.roles.superAdminNote") : $t("rbac.roles.systemNote") }}
          </p>
          <div class="grid grid-cols-2 gap-2">
            <div class="rounded-lg border bg-white p-3">
              <p class="text-xs text-muted-foreground">{{ $t("rbac.matrix.granted") }}</p>
              <p class="text-lg font-bold">{{ grantedCount(detailRole, permissions) }} / {{ permissions.length }}</p>
            </div>
            <div class="rounded-lg border bg-white p-3">
              <p class="text-xs text-muted-foreground">{{ $t("rbac.matrix.assigned") }}</p>
              <p class="text-lg font-bold text-primary">{{ $t("rbac.roles.staffCount", { n: detailRole.staffCount }) }}</p>
            </div>
          </div>
        </div>

        <div class="space-y-2">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold">{{ $t("rbac.roles.staff", { n: detailHolders.length }) }}</p>
            <router-link :to="{ name: 'settings', query: { role: detailRole.id } }" class="text-xs font-semibold text-primary hover:underline">
              + {{ $t("rbac.roles.assign") }}
            </router-link>
          </div>
          <p v-if="detailHolders.length === 0" class="rounded-lg border border-dashed px-3 py-4 text-center text-xs text-muted-foreground">
            {{ $t("rbac.roles.staffEmpty") }}
          </p>
          <ul v-else class="space-y-1.5">
            <li
              v-for="holder in detailHolders"
              :key="`${holder.staff.id}-${holder.branchId}`"
              class="flex items-center gap-3 rounded-lg border px-3 py-2"
            >
              <Avatar class="size-8">
                <AvatarImage v-if="holder.staff.photoUrl" :src="holder.staff.photoUrl" />
                <AvatarFallback class="bg-primary/10 text-xs text-primary">{{ initials(holder.staff.name) }}</AvatarFallback>
              </Avatar>
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold">{{ holder.staff.name }}</p>
                <p class="truncate text-xs text-muted-foreground">{{ branchName(holder.branchId) }}</p>
              </div>
            </li>
          </ul>
        </div>

        <Button v-if="canManage" class="w-full" as-child>
          <router-link :to="{ name: 'settings', query: { role: detailRole.id } }">
            <SquarePen class="mr-2 size-4" />
            {{ $t("rbac.matrix.editRole") }}
          </router-link>
        </Button>
      </aside>
    </div>
  </RbacLayout>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { Icon } from "@iconify/vue";
import { ChevronDown, Crown, IdCard, Plus, Save, Search, SquarePen, UserCog, X } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useCanManageRbac } from "@/composables/usePermission";
import { useBranches } from "@/queries/branches";
import { usePermissionsList } from "@/queries/permissions";
import { useRolesList, useUpdateRole } from "@/queries/roles";
import { useStaffList } from "@/queries/staff";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { initials } from "@/views/admin/pets/format";
import RbacLayout from "../RbacLayout.vue";
import {
  CUSTOMER_ROLE,
  fold,
  grantedCount,
  groupByModule,
  methodsOf,
  moduleIcon,
  roleMethods,
  SUPER_ADMIN_ROLE,
  type Method,
} from "../rbac";

const ALL = "all";
const CLOSED = "";

const { t } = useI18n();

const permissionsQuery = usePermissionsList();
const canManage = useCanManageRbac();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const rolesQuery = useRolesList();
// Customers never hold staff permissions, so they have no column.
const staffRoles = computed(() => (rolesQuery.data.value ?? []).filter((role) => role.name !== CUSTOMER_ROLE));
const staffQuery = useStaffList();
const branchesQuery = useBranches();
const loading = computed(() => permissionsQuery.isPending.value || rolesQuery.isPending.value);
const updateRole = useUpdateRole();

const search = ref("");
const moduleFilter = ref(ALL);
const quickEdit = ref(false);
const saving = ref(false);
const collapsed = ref<Record<string, boolean>>({});

const groups = computed(() =>
  groupByModule(permissions.value).map((group) => ({ ...group, key: group.module ?? "_" }))
);

const moduleChips = computed(() => [
  { key: ALL, label: t("petCare.common.all"), count: permissions.value.length },
  ...groups.value.map((group) => ({
    key: group.key,
    label: group.module ?? t("rbac.ungrouped"),
    count: group.items.length,
  })),
]);

const visibleGroups = computed(() => {
  const text = fold(search.value);
  return groups.value
    .filter((group) => moduleFilter.value === ALL || group.key === moduleFilter.value)
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

// Quick edit: role name -> permission id -> methods, only for cells changed since the last save.
const edits = ref<Record<string, Record<string, Method[]>>>({});
const editCount = computed(() =>
  Object.values(edits.value).reduce((sum, cells) => sum + Object.keys(cells).length, 0)
);

const cellMethods = (role: Role, permission: Permission): Method[] =>
  edits.value[role.name]?.[permission.id] ?? roleMethods(role, permission);

const cellState = (role: Role, permission: Permission): boolean | "indeterminate" => {
  const count = cellMethods(role, permission).length;
  if (count === 0) return false;
  return count === methodsOf(permission).length ? true : "indeterminate";
};

/** Ticking a cell grants every method the permission offers; unticking removes them all. */
const toggleCell = (role: Role, permission: Permission, on: boolean) => {
  const next = on ? methodsOf(permission) : [];
  const saved = roleMethods(role, permission);
  const cells = { ...(edits.value[role.name] ?? {}) };
  if (next.length === saved.length && next.every((method) => saved.includes(method))) delete cells[permission.id];
  else cells[permission.id] = next;
  edits.value = { ...edits.value, [role.name]: cells };
};

const saveMatrix = async () => {
  saving.value = true;
  try {
    for (const [roleName, cells] of Object.entries(edits.value)) {
      const role = staffRoles.value.find((item) => item.name === roleName);
      if (!role || Object.keys(cells).length === 0) continue;
      const permissionsInput = permissions.value
        .map((permission) => ({ id: permission.id, method: cells[permission.id] ?? roleMethods(role, permission) }))
        .filter((grant) => grant.method.length > 0);
      await updateRole.mutateAsync({
        id: role.id,
        input: { name: role.name, description: role.description, permissions: permissionsInput },
      });
      const { [roleName]: _done, ...rest } = edits.value;
      edits.value = rest;
    }
    quickEdit.value = false;
  } catch {
    // the mutation already showed the failure toast; unsaved roles keep their edits
  } finally {
    saving.value = false;
  }
};

// The side panel shows the clicked role; by default the first role that is not superAdmin.
const detailId = ref<string | null>(null);
const detailRole = computed(() => {
  if (detailId.value === CLOSED) return null;
  return (
    staffRoles.value.find((role) => role.id === detailId.value) ??
    staffRoles.value.find((role) => role.name !== SUPER_ADMIN_ROLE) ??
    null
  );
});

const detailHolders = computed(() =>
  (staffQuery.data.value ?? []).flatMap((member) =>
    member.assignments
      .filter((item) => item.role === detailRole.value?.name)
      .map((item) => ({ staff: member, branchId: item.branchId }))
  )
);

const branchName = (id: string): string => {
  const branch = (branchesQuery.data.value ?? []).find((item) => item.id === id);
  return branch ? `${branch.code} · ${branch.name}` : "";
};
</script>
