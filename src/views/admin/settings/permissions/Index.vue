<template>
  <RbacLayout>
    <template #actions>
      <Button @click="openForm(null)">
        <Plus class="mr-2 size-4" />
        {{ $t("rbac.permissions.add") }}
      </Button>
    </template>

    <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
      <div class="relative min-w-60 flex-1">
        <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input v-model="search" class="pl-9" :placeholder="$t('rbac.permissions.searchPlaceholder')" />
      </div>
      <Select v-model="moduleFilter">
        <SelectTrigger class="w-48" :aria-label="$t('rbac.permissions.filterModule')">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
          <SelectItem v-for="item in modules" :key="item" :value="item">{{ item }}</SelectItem>
          <SelectItem :value="UNGROUPED">{{ $t("rbac.ungrouped") }}</SelectItem>
        </SelectContent>
      </Select>
    </div>

    <div class="overflow-hidden rounded-xl border bg-white">
      <div class="flex items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
        <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
          {{ $t("petCare.common.showing", { count: filtered.length, total: permissions.length }) }}
        </span>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.module") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.methods") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("rbac.permissions.col.roles") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("rbac.permissions.col.actions") }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-if="permissionsQuery.isPending.value">
              <tr v-for="i in 5" :key="i" class="border-t">
                <td colspan="5" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
              </tr>
            </template>
            <tr v-else-if="filtered.length === 0">
              <td colspan="5" class="px-4 py-10 text-center text-muted-foreground">{{ $t("rbac.permissions.empty") }}</td>
            </tr>
            <tr v-for="permission in filtered" :key="permission.id" class="border-t hover:bg-muted/20">
              <td class="px-4 py-3">
                <p class="font-semibold">{{ permission.description || permission.name }}</p>
                <p class="font-mono text-xs text-muted-foreground">{{ permission.name }}</p>
              </td>
              <td class="px-4 py-3">
                <span class="rounded-full bg-muted px-2 py-0.5 text-[11px] font-medium text-muted-foreground">
                  {{ permission.module || $t("rbac.ungrouped") }}
                </span>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap gap-1">
                  <span
                    v-for="method in methodsOf(permission)"
                    :key="method"
                    class="flex items-center gap-1 rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
                  >
                    <Icon :icon="METHOD_ICONS[method]" class="size-3" />
                    {{ $t(`rbac.methods.${method}`) }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap gap-1">
                  <router-link
                    v-for="role in rolesUsing(permission.id)"
                    :key="role.id"
                    :to="{ name: 'settings', query: { role: role.id } }"
                    class="rounded-full border px-2 py-0.5 text-[11px] font-medium hover:border-primary hover:text-primary"
                  >
                    {{ role.description || role.name }}
                  </router-link>
                  <span v-if="rolesUsing(permission.id).length === 0" class="text-xs text-muted-foreground">—</span>
                </div>
              </td>
              <td class="px-4 py-3 text-right">
                <DropdownMenu>
                  <DropdownMenuTrigger as-child>
                    <Button variant="ghost" size="icon" class="size-8">
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
import { computed, ref } from "vue";
import { Icon } from "@iconify/vue";
import { EllipsisVertical, Plus, Search } from "lucide-vue-next";
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
import { useDeletePermission, usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import type { Permission } from "@/repositories/permissions";
import RbacLayout from "../RbacLayout.vue";
import { METHOD_ICONS, methodsOf } from "../rbac";
import PermissionFormSheet from "./PermissionFormSheet.vue";

const ALL = "all";
const UNGROUPED = "__ungrouped";

/** Lowercase without Vietnamese accents, so "quyen" finds "Quyền". */
const fold = (text: string): string =>
  text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/đ/gi, "d").toLowerCase().trim();

const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const deletePermission = useDeletePermission();

const search = ref("");
const moduleFilter = ref(ALL);
const formOpen = ref(false);
const editing = ref<Permission | null>(null);
const toDelete = ref<Permission | null>(null);

const modules = computed(() =>
  [...new Set(permissions.value.map((item) => item.module?.trim()).filter((item): item is string => !!item))].sort()
);

const filtered = computed(() => {
  const text = fold(search.value);
  return permissions.value.filter((permission) => {
    const module = permission.module?.trim() || null;
    if (moduleFilter.value === UNGROUPED && module) return false;
    if (moduleFilter.value !== ALL && moduleFilter.value !== UNGROUPED && module !== moduleFilter.value) return false;
    if (!text) return true;
    return fold(`${permission.name} ${permission.description ?? ""}`).includes(text);
  });
});

const rolesUsing = (permissionId: string) =>
  roles.value.filter((role) => role.permissions.some((grant) => grant.id === permissionId && grant.method.length > 0));

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
