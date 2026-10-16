<template>
  <RbacLayout :eyebrow="$t('rbac.eyebrow')">
    <template #actions>
      <Button v-if="canManage" @click="startNew(null)">
        <Plus class="mr-2 size-4" />
        {{ $t("rbac.roles.add") }}
      </Button>
    </template>

    <template #summary>
      <div class="flex flex-wrap items-center gap-x-6 gap-y-2 rounded-xl border bg-white px-4 py-2 text-sm">
        <span class="flex items-center gap-2 text-muted-foreground">
          <span class="size-2 rounded-full bg-emerald-500" />
          {{ $t("rbac.roles.assignedStaff") }}
          <b class="text-foreground">{{ $t("rbac.roles.staffCount", { n: assignedStaff }) }}</b>
        </span>
        <span v-if="unassignedStaff > 0" class="text-muted-foreground">
          {{ $t("rbac.roles.unassignedStaff") }}
          <b class="text-amber-600">{{ unassignedStaff }}</b>
        </span>
      </div>
    </template>

    <div class="grid items-start gap-5 lg:grid-cols-[320px_minmax(0,1fr)]">
      <aside class="space-y-3 rounded-xl border bg-white p-3 lg:sticky lg:top-4">
        <div class="flex items-center justify-between px-1">
          <h3 class="text-sm font-semibold">{{ $t("rbac.roles.listTitle") }}</h3>
          <span class="text-xs text-muted-foreground">{{ $t("rbac.roles.listCount", { n: roles.length }) }}</span>
        </div>
        <div class="relative">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('rbac.roles.searchPlaceholder')" />
        </div>

        <div v-if="rolesQuery.isPending.value" class="space-y-2">
          <Skeleton v-for="i in 4" :key="i" class="h-24 w-full" />
        </div>
        <ul v-else class="space-y-2">
          <li v-if="creating">
            <div class="rounded-lg border border-l-4 border-primary bg-primary/5 px-3 py-3">
              <p class="font-semibold text-primary">{{ template ? $t("rbac.roles.cloneOf", { name: label(template) }) : $t("rbac.roles.new") }}</p>
              <p class="text-xs text-muted-foreground">{{ $t("rbac.roles.newHint") }}</p>
            </div>
          </li>
          <RoleListItem
            v-for="role in visibleRoles"
            :key="role.id"
            :role="role"
            :selected="isSelected(role)"
            :holders="holdersOf(role)"
            :granted="grantedCount(role, permissions)"
            :permission-count="permissions.length"
            :can-manage="canManage"
            @select="select(role.id)"
            @clone="startNew(role)"
            @remove="toDelete = role"
          />
          <li v-if="visibleRoles.length === 0" class="px-2 py-6 text-center text-sm text-muted-foreground">
            {{ $t("rbac.roles.noMatch") }}
          </li>
        </ul>
      </aside>

      <RoleEditor
        v-if="creating || selected"
        :role="creating ? null : selected"
        :template="creating ? template : null"
        :roles="roles"
        :permissions="permissions"
        :staff="staff"
        :branches="branches"
        @saved="onSaved"
        @cancel-new="creating = false"
      />
      <div v-else class="rounded-xl border bg-white px-4 py-16 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.empty") }}
      </div>
    </div>

    <ConfirmDialog
      :open="!!toDelete"
      :title="$t('rbac.roles.confirmDeleteTitle', { name: toDelete ? label(toDelete) : '' })"
      :desc="$t('rbac.roles.confirmDeleteDesc')"
      :ok-btn="$t('rbac.roles.delete')"
      @open-change="toDelete = null"
      @cancel="toDelete = null"
      @handle-ok="remove"
    />
  </RbacLayout>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus, Search } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useCanManageRbac } from "@/composables/usePermission";
import { useBranches } from "@/queries/branches";
import { usePermissionsList } from "@/queries/permissions";
import { useDeleteRole, useRolesList } from "@/queries/roles";
import { useStaffList } from "@/queries/staff";
import type { Role } from "@/repositories/roles";
import RbacLayout from "../RbacLayout.vue";
import { fold, grantedCount } from "../rbac";
import RoleEditor from "./RoleEditor.vue";
import RoleListItem from "./RoleListItem.vue";
import { useRoleSelection } from "./useRoleSelection";

const canManage = useCanManageRbac();

const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const staffQuery = useStaffList();
const staff = computed(() => staffQuery.data.value ?? []);
const branchesQuery = useBranches();
const branches = computed(() => branchesQuery.data.value ?? []);
const deleteRole = useDeleteRole();

const { creating, template, selected, isSelected, select, startNew, clearIfSelected } = useRoleSelection(
  () => roles.value,
  () => canManage.value
);

const search = ref("");
const toDelete = ref<Role | null>(null);

const label = (role: Role): string => role.description || role.name;

const visibleRoles = computed(() => {
  const text = fold(search.value);
  if (!text) return roles.value;
  return roles.value.filter((role) => fold(`${role.name} ${role.description ?? ""}`).includes(text));
});

const holdersOf = (role: Role) =>
  staff.value.filter((member) => member.assignments.some((item) => item.role === role.name));

const assignedStaff = computed(() => staff.value.filter((member) => member.assignments.length > 0).length);
const unassignedStaff = computed(() => staff.value.length - assignedStaff.value);

const onSaved = (name: string) => select(name);

const remove = async () => {
  const target = toDelete.value;
  toDelete.value = null;
  if (!target) return;
  try {
    await deleteRole.mutateAsync(target.id);
  } catch {
    return; // the mutation already showed the failure toast
  }
  clearIfSelected(target.id);
};
</script>
