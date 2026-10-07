<template>
  <RbacLayout :eyebrow="$t('rbac.eyebrow')">
    <template #actions>
      <Button @click="startNew(null)">
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
          <li v-for="role in visibleRoles" :key="role.id" class="relative">
            <button
              type="button"
              class="w-full rounded-lg border border-l-4 px-3 py-3 pr-10 text-left transition-colors"
              :class="isSelected(role) ? 'border-primary bg-primary/5' : 'border-l-transparent hover:bg-muted/40'"
              @click="select(role.id)"
            >
              <span class="flex items-center gap-2">
                <span class="truncate font-semibold" :class="isSelected(role) ? 'text-primary' : ''">{{ label(role) }}</span>
                <span
                  v-if="role.isSystem"
                  class="shrink-0 rounded-full bg-muted px-1.5 py-0.5 text-[10px] font-semibold text-muted-foreground"
                >
                  {{ $t("rbac.system") }}
                </span>
              </span>
              <span class="mt-0.5 block font-mono text-[11px] text-muted-foreground">{{ role.name }}</span>
              <span class="mt-2.5 flex items-center justify-between gap-2">
                <span class="flex items-center gap-2 text-xs text-muted-foreground">
                  <span v-if="holdersOf(role).length" class="flex -space-x-2">
                    <Avatar v-for="member in holdersOf(role).slice(0, 3)" :key="member.id" class="size-6 border-2 border-white">
                      <AvatarImage v-if="member.photoUrl" :src="member.photoUrl" />
                      <AvatarFallback class="bg-primary/10 text-[9px] text-primary">{{ initials(member.name) }}</AvatarFallback>
                    </Avatar>
                    <span
                      v-if="holdersOf(role).length > 3"
                      class="flex size-6 items-center justify-center rounded-full border-2 border-white bg-muted text-[9px] font-semibold"
                    >
                      +{{ holdersOf(role).length - 3 }}
                    </span>
                  </span>
                  {{ $t("rbac.roles.staffCount", { n: role.staffCount }) }}
                </span>
                <span
                  v-if="role.name !== CUSTOMER_ROLE"
                  class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
                  :class="grantedCount(role, permissions) === permissions.length && permissions.length > 0
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-primary/10 text-primary'"
                >
                  {{ role.name === SUPER_ADMIN_ROLE
                    ? $t("rbac.roles.fullAccess", { n: permissions.length })
                    : $t("rbac.roles.grantRatio", { n: grantedCount(role, permissions), total: permissions.length }) }}
                </span>
              </span>
            </button>
            <DropdownMenu>
              <DropdownMenuTrigger as-child>
                <Button variant="ghost" size="icon" class="absolute right-1.5 top-2 size-8" :aria-label="$t('rbac.roles.more')">
                  <EllipsisVertical class="size-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem v-if="role.name !== SUPER_ADMIN_ROLE" @click="startNew(role)">
                  <Copy class="mr-2 size-4" />
                  {{ $t("rbac.roles.clone") }}
                </DropdownMenuItem>
                <DropdownMenuItem :disabled="role.isSystem" class="text-red-600" @click="toDelete = role">
                  <Trash2 class="mr-2 size-4" />
                  {{ $t("rbac.roles.delete") }}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </li>
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
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { Copy, EllipsisVertical, Plus, Search, Trash2 } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useBranches } from "@/queries/branches";
import { usePermissionsList } from "@/queries/permissions";
import { useDeleteRole, useRolesList } from "@/queries/roles";
import { useStaffList } from "@/queries/staff";
import type { Role } from "@/repositories/roles";
import { initials } from "@/views/admin/pets/format";
import RbacLayout from "../RbacLayout.vue";
import { CUSTOMER_ROLE, fold, grantedCount, SUPER_ADMIN_ROLE } from "../rbac";
import RoleEditor from "./RoleEditor.vue";

const route = useRoute();
const router = useRouter();

const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const staffQuery = useStaffList();
const staff = computed(() => staffQuery.data.value ?? []);
const branchesQuery = useBranches();
const branches = computed(() => branchesQuery.data.value ?? []);
const deleteRole = useDeleteRole();

const search = ref("");
const creating = ref(false);
// Role whose name, description and grants seed a new role ("Nhân bản").
const template = ref<Role | null>(null);
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

// The selected role lives in the URL (?role=cashier) so the matrix can link straight to it.
const selectedId = computed(() => (typeof route.query.role === "string" ? route.query.role : null));
const selected = computed(
  () => roles.value.find((role) => role.id === selectedId.value) ?? roles.value[0] ?? null
);
const isSelected = (role: Role): boolean => !creating.value && selected.value?.id === role.id;

const select = (id: string) => {
  creating.value = false;
  router.replace({ query: { ...route.query, role: id, new: undefined } });
};

const startNew = (from: Role | null) => {
  template.value = from;
  creating.value = true;
};

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
  if (selected.value?.id === target.id) router.replace({ query: { ...route.query, role: undefined } });
};

watch(selectedId, (id) => {
  if (id) creating.value = false;
});

// The matrix screen's "Thêm vai trò" button links here with ?new=1.
watch(
  () => route.query.new,
  (value) => {
    if (value) startNew(null);
  },
  { immediate: true }
);
</script>
