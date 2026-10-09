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

    <PermissionStatCards :cards="statCards" />

    <PermissionFilters
      v-model:search="search"
      v-model:module-filter="moduleFilter"
      v-model:method-filter="methodFilter"
      v-model:only-unused="onlyUnused"
      :modules="modules"
      :top-modules="topModules"
      :unused-count="unusedCount"
      :matched="filtered.length"
      :total="permissions.length"
      @reset="resetFilters"
    />

    <PagedTableCard
      v-model:page="page"
      v-model:page-size="pageSize"
      :page-count="pageCount"
      :count="pageItems.length"
      :total="filtered.length"
    >
      <table class="w-full text-sm">
        <thead>
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
          <TableStateRows :colspan="6" :pending="permissionsQuery.isPending.value" :empty="filtered.length === 0" :empty-text="$t('rbac.permissions.empty')" skeleton-class="h-10 w-full" />
          <PermissionRow
            v-for="permission in pageItems"
            :key="permission.id"
            :permission="permission"
            :used-by="rolesUsing(permission.id)"
            :can-manage="canManage"
            @edit="openForm"
            @remove="toDelete = $event"
          />
        </tbody>
      </table>
    </PagedTableCard>

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
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { Download, Plus, ShieldCheck } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { useCanManageRbac } from "@/composables/usePermission";
import { useDeletePermission, usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import type { Permission } from "@/repositories/permissions";
import RbacLayout from "../RbacLayout.vue";
import { exportPermissionsCsv } from "./exportPermissionsCsv";
import PermissionFilters from "./PermissionFilters.vue";
import PermissionFormSheet from "./PermissionFormSheet.vue";
import PermissionRow from "./PermissionRow.vue";
import PermissionStatCards from "./PermissionStatCards.vue";
import { usePermissionCatalog } from "./usePermissionCatalog";
import { usePermissionsFilter } from "./usePermissionsFilter";

const { t } = useI18n();

const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const deletePermission = useDeletePermission();
const canManage = useCanManageRbac();

const { modules, topModules, rolesUsing, unusedCount, statCards } = usePermissionCatalog(
  () => permissions.value,
  () => roles.value
);
const {
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
} = usePermissionsFilter(() => permissions.value, rolesUsing);

const formOpen = ref(false);
const editing = ref<Permission | null>(null);
const toDelete = ref<Permission | null>(null);

const exportCsv = () => exportPermissionsCsv(filtered.value, roles.value, t);

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
