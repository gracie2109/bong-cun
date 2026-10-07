<template>
  <div class="space-y-5">
    <section class="space-y-4 rounded-xl border bg-white p-5">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="flex items-center gap-2">
          <h3 class="text-lg font-bold">{{ role ? role.name : $t("rbac.roles.new") }}</h3>
          <span
            v-if="role?.isSystem"
            class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground"
          >
            {{ $t("rbac.system") }}
          </span>
          <span v-if="dirty" class="rounded-full bg-amber-50 px-2 py-0.5 text-[11px] font-medium text-amber-700">
            {{ $t("rbac.roles.unsaved") }}
          </span>
        </div>
        <div class="flex gap-2">
          <Button
            v-if="role && !role.isSystem"
            type="button"
            variant="outline"
            class="text-red-600 hover:text-red-700"
            :disabled="pending"
            @click="confirmDelete = true"
          >
            <Trash2 class="mr-2 size-4" />
            {{ $t("rbac.roles.delete") }}
          </Button>
          <Button type="button" variant="outline" :disabled="!dirty || pending" @click="reset">
            {{ $t("petCare.common.cancel") }}
          </Button>
          <Button type="button" :disabled="pending || (!dirty && !!role)" @click="save">
            {{ $t("petCare.common.save") }}
          </Button>
        </div>
      </div>

      <p v-if="role?.isSystem" class="rounded-lg bg-muted/60 px-3 py-2 text-sm text-muted-foreground">
        {{ $t("rbac.roles.systemNote") }}
      </p>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-2">
          <Label for="role-name">{{ $t("rbac.roles.name") }}</Label>
          <Input id="role-name" v-model="name" :disabled="role?.isSystem" autocomplete="off" />
          <p v-if="submitted && !nameValid" class="text-sm text-red-600">{{ $t("rbac.roles.errName") }}</p>
          <p v-else class="text-xs text-muted-foreground">{{ $t("rbac.roles.nameHint") }}</p>
        </div>
        <div class="space-y-2">
          <Label for="role-desc">{{ $t("rbac.roles.desc") }}</Label>
          <Input id="role-desc" v-model="description" />
        </div>
      </div>
    </section>

    <section class="overflow-hidden rounded-xl border bg-white">
      <div class="flex flex-wrap items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
        <div>
          <h4 class="font-semibold">{{ $t("rbac.roles.grid") }}</h4>
          <p class="text-xs text-muted-foreground">
            {{ isSuperAdmin ? $t("rbac.roles.superAdminNote") : $t("rbac.roles.gridHint") }}
          </p>
        </div>
        <div v-if="!isSuperAdmin && permissions.length" class="flex gap-2">
          <Button type="button" variant="ghost" size="sm" @click="setEverything(true)">
            {{ $t("rbac.roles.selectAll") }}
          </Button>
          <Button type="button" variant="ghost" size="sm" @click="setEverything(false)">
            {{ $t("rbac.roles.clearAll") }}
          </Button>
        </div>
      </div>

      <p v-if="!permissions.length" class="px-4 py-10 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.noPermissions") }}
      </p>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 text-left font-semibold">{{ $t("rbac.roles.permission") }}</th>
              <th class="px-2 py-3 text-center font-semibold">{{ $t("rbac.roles.allRow") }}</th>
              <th v-for="method in METHODS" :key="method" class="px-2 py-3 text-center font-semibold">
                <div class="flex flex-col items-center gap-1.5">
                  <span>{{ $t(`rbac.methods.${method}`) }}</span>
                  <Checkbox
                    :checked="columnState(method)"
                    :disabled="isSuperAdmin || !columnOffered(method)"
                    :aria-label="$t(`rbac.methods.${method}`)"
                    @update:checked="(value: boolean | 'indeterminate') => setColumn(method, value === true)"
                  />
                </div>
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="group in groups" :key="group.module ?? '_'">
              <tr class="border-t bg-muted/30">
                <td :colspan="METHODS.length + 2" class="px-4 py-2 text-xs font-semibold uppercase tracking-wide text-primary">
                  {{ group.module ?? $t("rbac.ungrouped") }}
                </td>
              </tr>
              <tr v-for="permission in group.items" :key="permission.id" class="border-t hover:bg-muted/20">
                <td class="px-4 py-2.5">
                  <p class="font-medium">{{ permission.description || permission.name }}</p>
                  <p class="font-mono text-[11px] text-muted-foreground">{{ permission.name }}</p>
                </td>
                <td class="px-2 py-2.5 text-center">
                  <Checkbox
                    :checked="rowState(permission)"
                    :disabled="isSuperAdmin"
                    :aria-label="`${permission.name} ${$t('rbac.roles.allRow')}`"
                    @update:checked="(value: boolean | 'indeterminate') => setRow(permission, value === true)"
                  />
                </td>
                <td v-for="method in METHODS" :key="method" class="px-2 py-2.5 text-center">
                  <Checkbox
                    v-if="methodsOf(permission).includes(method)"
                    :checked="isSuperAdmin || has(permission.id, method)"
                    :disabled="isSuperAdmin"
                    :aria-label="`${permission.name} ${$t(`rbac.methods.${method}`)}`"
                    @update:checked="(value: boolean | 'indeterminate') => setCell(permission.id, method, value === true)"
                  />
                  <span v-else class="text-muted-foreground/40">·</span>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <section v-if="role && role.name !== CUSTOMER_ROLE" class="rounded-xl border bg-white">
      <div class="flex items-center justify-between gap-3 border-b px-4 py-3">
        <h4 class="font-semibold">{{ $t("rbac.roles.staff") }}</h4>
        <Button type="button" variant="outline" size="sm" @click="assignOpen = true">
          <UserPlus class="mr-2 size-4" />
          {{ $t("rbac.roles.assign") }}
        </Button>
      </div>
      <p v-if="holders.length === 0" class="px-4 py-6 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.staffEmpty") }}
      </p>
      <ul v-else class="divide-y">
        <li v-for="holder in holders" :key="`${holder.staff.id}-${holder.branchId}`" class="flex items-center gap-3 px-4 py-2.5">
          <Avatar class="size-8">
            <AvatarImage v-if="holder.staff.photoUrl" :src="holder.staff.photoUrl" />
            <AvatarFallback class="text-xs">{{ initials(holder.staff.name) }}</AvatarFallback>
          </Avatar>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium">{{ holder.staff.name }}</p>
            <p class="truncate text-xs text-muted-foreground">{{ holder.staff.email }}</p>
          </div>
          <span v-if="branches.length > 1" class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
            {{ branchCode(holder.branchId) }}
          </span>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            class="text-red-600 hover:text-red-700"
            :disabled="saveStaff.isPending.value"
            @click="removeHolder(holder.staff, holder.branchId)"
          >
            {{ $t("rbac.roles.remove") }}
          </Button>
        </li>
      </ul>
    </section>

    <AssignStaffSheet
      v-if="role"
      v-model:open="assignOpen"
      :role="role.name"
      :staff="staff"
      :branches="branches"
      :roles="roles"
    />

    <ConfirmDialog
      :open="confirmDelete"
      :title="$t('rbac.roles.confirmDeleteTitle', { name: role?.name ?? '' })"
      :desc="$t('rbac.roles.confirmDeleteDesc')"
      :ok-btn="$t('rbac.roles.delete')"
      @open-change="confirmDelete = false"
      @cancel="confirmDelete = false"
      @handle-ok="remove"
    />
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Trash2, UserPlus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useCreateRole, useDeleteRole, useUpdateRole } from "@/queries/roles";
import { useSaveStaffAssignments } from "@/queries/staff";
import type { Branch } from "@/repositories/branches";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import type { StaffMember } from "@/repositories/staff";
import { initials } from "@/views/admin/pets/format";
import AssignStaffSheet from "./AssignStaffSheet.vue";
import { grantedMethods, groupByModule, METHODS, methodsOf, ROLE_CODE_PATTERN, type Method } from "../rbac";

const SUPER_ADMIN_ROLE = "superAdmin";
const CUSTOMER_ROLE = "customer";

const props = defineProps<{
  role: Role | null;
  roles: Role[];
  permissions: Permission[];
  staff: StaffMember[];
  branches: Branch[];
}>();

const emit = defineEmits<{ saved: [name: string]; deleted: [] }>();

const createRole = useCreateRole();
const updateRole = useUpdateRole();
const deleteRole = useDeleteRole();
const saveStaff = useSaveStaffAssignments();

const name = ref("");
const description = ref("");
const grants = ref<Record<string, Method[]>>({});
const submitted = ref(false);
const confirmDelete = ref(false);
const assignOpen = ref(false);

const groups = computed(() => groupByModule(props.permissions));
const isSuperAdmin = computed(() => props.role?.name === SUPER_ADMIN_ROLE);
const nameValid = computed(() => ROLE_CODE_PATTERN.test(name.value.trim()));
const pending = computed(
  () => createRole.isPending.value || updateRole.isPending.value || deleteRole.isPending.value
);

const grantsOf = (role: Role | null): Record<string, Method[]> =>
  Object.fromEntries(
    props.permissions
      .map((permission) => [permission.id, role ? grantedMethods(role.permissions, permission) : []] as const)
      .filter(([, methods]) => methods.length > 0)
  );

const snapshot = (value: { name: string; description: string; grants: Record<string, Method[]> }) =>
  JSON.stringify({
    name: value.name.trim(),
    description: value.description.trim(),
    grants: Object.keys(value.grants)
      .filter((id) => value.grants[id].length > 0)
      .sort()
      .map((id) => [id, [...value.grants[id]].sort()]),
  });

const initial = computed(() =>
  snapshot({
    name: props.role?.name ?? "",
    description: props.role?.description ?? "",
    grants: grantsOf(props.role),
  })
);
const dirty = computed(
  () => snapshot({ name: name.value, description: description.value, grants: grants.value }) !== initial.value
);

const reset = () => {
  name.value = props.role?.name ?? "";
  description.value = props.role?.description ?? "";
  grants.value = grantsOf(props.role);
  submitted.value = false;
};

watch(() => [props.role, props.permissions] as const, reset, { immediate: true });

const has = (permissionId: string, method: Method): boolean =>
  grants.value[permissionId]?.includes(method) ?? false;

const setCell = (permissionId: string, method: Method, on: boolean) => {
  const current = grants.value[permissionId] ?? [];
  const next = on ? [...new Set([...current, method])] : current.filter((item) => item !== method);
  grants.value = { ...grants.value, [permissionId]: METHODS.filter((item) => next.includes(item)) };
};

const rowState = (permission: Permission): boolean | "indeterminate" => {
  if (isSuperAdmin.value) return true;
  const count = grants.value[permission.id]?.length ?? 0;
  if (count === 0) return false;
  return count === methodsOf(permission).length ? true : "indeterminate";
};

const setRow = (permission: Permission, on: boolean) => {
  grants.value = { ...grants.value, [permission.id]: on ? methodsOf(permission) : [] };
};

const columnOffered = (method: Method): boolean =>
  props.permissions.some((permission) => methodsOf(permission).includes(method));

const columnState = (method: Method): boolean | "indeterminate" => {
  if (isSuperAdmin.value) return true;
  const offering = props.permissions.filter((permission) => methodsOf(permission).includes(method));
  const granted = offering.filter((permission) => has(permission.id, method)).length;
  if (granted === 0) return false;
  return granted === offering.length ? true : "indeterminate";
};

const setColumn = (method: Method, on: boolean) => {
  for (const permission of props.permissions) {
    if (methodsOf(permission).includes(method)) setCell(permission.id, method, on);
  }
};

const setEverything = (on: boolean) => {
  for (const permission of props.permissions) setRow(permission, on);
};

const save = async () => {
  submitted.value = true;
  if (!nameValid.value) return;
  const input = {
    name: name.value.trim(),
    description: description.value.trim() || null,
    permissions: Object.entries(grants.value)
      .filter(([, methods]) => methods.length > 0)
      .map(([id, method]) => ({ id, method })),
  };
  try {
    if (props.role) await updateRole.mutateAsync({ id: props.role.id, input });
    else await createRole.mutateAsync(input);
  } catch {
    return; // the mutation already showed the failure toast
  }
  emit("saved", input.name);
};

const remove = async () => {
  confirmDelete.value = false;
  if (!props.role) return;
  try {
    await deleteRole.mutateAsync(props.role.id);
  } catch {
    return;
  }
  emit("deleted");
};

const holders = computed(() =>
  props.staff.flatMap((member) =>
    member.assignments
      .filter((item) => item.role === props.role?.name)
      .map((item) => ({ staff: member, branchId: item.branchId }))
  )
);

const branchCode = (id: string): string => props.branches.find((branch) => branch.id === id)?.code ?? "";

const removeHolder = (member: StaffMember, branchId: string) =>
  saveStaff.mutate({
    userId: member.id,
    assignments: member.assignments.filter((item) => item.branchId !== branchId),
  });
</script>
