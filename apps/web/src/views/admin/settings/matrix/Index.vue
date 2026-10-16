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
        <MatrixToolbar
          v-model:search="search"
          v-model:quick-edit="quickEdit"
          v-model:module-filter="moduleFilter"
          :can-manage="canManage"
          :permission-count="permissions.length"
          :chips="moduleChips"
        />

        <MatrixTable
          v-model:collapsed="collapsed"
          :loading="loading"
          :roles="staffRoles"
          :groups="visibleGroups"
          :shown="visibleCount"
          :total="permissions.length"
          :detail-role-id="detailRole?.id"
          :quick-edit="quickEdit"
          :all-collapsed="allCollapsed"
          :cell-state="cellState"
          :cell-methods="cellMethods"
          @toggle-all="setAllCollapsed(!allCollapsed)"
          @select-role="detailId = $event"
          @toggle-cell="toggleCell"
        />
      </div>

      <MatrixRoleDetail
        v-if="detailRole"
        :role="detailRole"
        :permissions="permissions"
        :can-manage="canManage"
        @close="detailId = CLOSED"
      />
    </div>
  </RbacLayout>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus, Save } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useCanManageRbac } from "@/composables/usePermission";
import { usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import RbacLayout from "../RbacLayout.vue";
import { CUSTOMER_ROLE, SUPER_ADMIN_ROLE } from "../rbac";
import MatrixRoleDetail from "./MatrixRoleDetail.vue";
import MatrixTable from "./MatrixTable.vue";
import MatrixToolbar from "./MatrixToolbar.vue";
import { useMatrixEdits } from "./useMatrixEdits";
import { useMatrixView } from "./useMatrixView";

const CLOSED = "";

const permissionsQuery = usePermissionsList();
const canManage = useCanManageRbac();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const rolesQuery = useRolesList();
// Customers never hold staff permissions, so they have no column.
const staffRoles = computed(() => (rolesQuery.data.value ?? []).filter((role) => role.name !== CUSTOMER_ROLE));
const loading = computed(() => permissionsQuery.isPending.value || rolesQuery.isPending.value);

const { search, moduleFilter, collapsed, moduleChips, visibleGroups, visibleCount, allCollapsed, setAllCollapsed } =
  useMatrixView(() => permissions.value);
const { quickEdit, saving, editCount, cellMethods, cellState, toggleCell, saveMatrix } = useMatrixEdits(
  () => staffRoles.value,
  () => permissions.value
);

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
</script>
