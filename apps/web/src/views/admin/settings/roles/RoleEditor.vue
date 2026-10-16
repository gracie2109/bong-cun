<template>
  <div class="space-y-5">
    <section class="space-y-5 rounded-xl border bg-white p-5">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="flex items-start gap-3">
          <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <UserCog class="size-5" />
          </span>
          <div>
            <h3 class="flex flex-wrap items-center gap-2 text-lg font-bold">
              {{ role ? $t("rbac.roles.configTitle", { name: role.description || role.name }) : $t("rbac.roles.new") }}
              <span
                v-if="role?.isSystem"
                class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground"
              >
                {{ $t("rbac.system") }}
              </span>
            </h3>
            <p class="text-sm text-muted-foreground">{{ $t("rbac.roles.configHint") }}</p>
          </div>
        </div>
        <div v-if="canManage" class="flex gap-2">
          <Button v-if="role" type="button" variant="ghost" :disabled="!dirty || pending" @click="reset">
            <RotateCcw class="mr-2 size-4" />
            {{ $t("rbac.roles.restore") }}
          </Button>
          <Button v-else type="button" variant="ghost" :disabled="pending" @click="emit('cancelNew')">
            {{ $t("petCare.common.cancel") }}
          </Button>
          <Button type="button" :disabled="pending || (!dirty && !!role)" @click="save">
            {{ $t("rbac.roles.saveChanges") }}
          </Button>
        </div>
      </div>

      <p v-if="role?.isSystem" class="rounded-lg bg-muted/60 px-3 py-2 text-sm text-muted-foreground">
        {{ $t("rbac.roles.systemNote") }}
      </p>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-2">
          <Label for="role-desc">{{ $t("rbac.roles.desc") }}</Label>
          <Input id="role-desc" v-model="description" :readonly="!canManage" :placeholder="$t('rbac.roles.descPlaceholder')" />
        </div>
        <div class="space-y-2">
          <Label for="role-name">{{ $t("rbac.roles.name") }} <span v-if="!role" class="text-red-600">*</span></Label>
          <div class="relative">
            <Input
              id="role-name"
              v-model="name"
              :readonly="!!role"
              class="font-mono text-sm"
              :class="role ? 'bg-muted/50 pr-9 text-muted-foreground' : ''"
              autocomplete="off"
            />
            <Lock v-if="role" class="absolute right-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          </div>
          <p v-if="submitted && !nameValid" class="text-sm text-red-600">{{ $t("rbac.roles.errName") }}</p>
          <p v-else class="text-xs text-muted-foreground">{{ role ? $t("rbac.roles.nameLocked") : $t("rbac.roles.nameHint") }}</p>
        </div>
      </div>

      <div
        v-if="role"
        class="flex flex-wrap items-center gap-x-5 gap-y-2 rounded-lg border bg-muted/30 px-3 py-2 text-xs text-muted-foreground"
      >
        <span class="flex items-center gap-1.5">
          <CalendarDays class="size-3.5" />
          {{ $t("rbac.roles.createdAt") }} <b class="text-foreground">{{ formatDate(role.createdAt) }}</b>
        </span>
        <span class="flex items-center gap-1.5">
          <Users class="size-3.5" />
          {{ $t("rbac.roles.appliedTo") }} <b class="text-foreground">{{ $t("rbac.roles.staffCount", { n: role.staffCount }) }}</b>
        </span>
        <button
          v-if="role.name !== CUSTOMER_ROLE"
          type="button"
          class="font-semibold text-primary hover:underline"
          @click="staffSection?.scrollIntoView()"
        >
          {{ $t("rbac.roles.viewStaff") }}
        </button>
      </div>
    </section>

    <section class="space-y-4 rounded-xl border bg-white p-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-3">
          <h4 class="text-lg font-bold">{{ $t("rbac.roles.grid") }}</h4>
          <span class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary">
            {{ $t("rbac.roles.selectedCount", { n: selectedCount, total: permissions.length }) }}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <div class="relative">
            <Filter class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input v-model="filter" class="h-9 w-56 pl-9" :placeholder="$t('rbac.roles.filterPlaceholder')" />
          </div>
          <Button type="button" variant="ghost" size="sm" @click="setAllOpen(true)">
            <ChevronsUpDown class="mr-1 size-4" />
            {{ $t("rbac.roles.expandAll") }}
          </Button>
          <Button type="button" variant="ghost" size="sm" @click="setAllOpen(false)">
            <ChevronsDownUp class="mr-1 size-4" />
            {{ $t("rbac.roles.collapseAll") }}
          </Button>
        </div>
      </div>

      <p class="text-xs text-muted-foreground">
        {{ isSuperAdmin ? $t("rbac.roles.superAdminNote") : $t("rbac.roles.gridHint") }}
      </p>

      <p v-if="!permissions.length" class="py-10 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.noPermissions") }}
      </p>
      <p v-else-if="!visibleGroups.length" class="py-10 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.noMatch") }}
      </p>

      <RolePermissionGroup
        v-for="group in visibleGroups"
        :key="group.key"
        :group="group"
        :open="openGroups[group.key] ?? true"
        :grants="grants"
        :is-super-admin="isSuperAdmin"
        :locked="locked"
        @update:open="openGroups[group.key] = $event"
        @set-group="setGroup"
        @set-row="setRow"
        @set-cell="setCell"
      />
    </section>

    <RoleStaffSection
      v-if="role && role.name !== CUSTOMER_ROLE"
      ref="staffSection"
      :role="role"
      :roles="roles"
      :staff="staff"
      :branches="branches"
      :can-manage="canManage"
    />

    <UnsavedChangesBar
      :visible="canManage && !!role && dirty"
      :change-count="changeCount"
      :role-label="role?.description || role?.name || ''"
      :pending="pending"
      @discard="reset"
      @save="save"
    />
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import {
  CalendarDays,
  ChevronsDownUp,
  ChevronsUpDown,
  Filter,
  Lock,
  RotateCcw,
  UserCog,
  Users,
} from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useCanManageRbac } from "@/composables/usePermission";
import { useCreateRole, useUpdateRole } from "@/queries/roles";
import type { Branch } from "@/repositories/branches";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import type { StaffMember } from "@/repositories/staff";
import { formatDate } from "@/views/admin/pets/format";
import { CUSTOMER_ROLE, ROLE_CODE_PATTERN, SUPER_ADMIN_ROLE } from "../rbac";
import RolePermissionGroup from "./RolePermissionGroup.vue";
import RoleStaffSection from "./RoleStaffSection.vue";
import UnsavedChangesBar from "./UnsavedChangesBar.vue";
import { usePermissionGroups } from "./usePermissionGroups";
import { useRoleGrants } from "./useRoleGrants";

const props = defineProps<{
  role: Role | null;
  /** For a new role: the role being cloned, whose description and grants are copied. */
  template?: Role | null;
  roles: Role[];
  permissions: Permission[];
  staff: StaffMember[];
  branches: Branch[];
}>();

const emit = defineEmits<{ saved: [name: string]; cancelNew: [] }>();

const { t } = useI18n();
const createRole = useCreateRole();
const updateRole = useUpdateRole();

const name = ref("");
const description = ref("");
const submitted = ref(false);
const staffSection = ref<InstanceType<typeof RoleStaffSection> | null>(null);

const isSuperAdmin = computed(() => props.role?.name === SUPER_ADMIN_ROLE);
const canManage = useCanManageRbac();
// superAdmin always holds everything; anyone but a superAdmin only looks.
const locked = computed(() => isSuperAdmin.value || !canManage.value);
const nameValid = computed(() => ROLE_CODE_PATTERN.test(name.value.trim()));
const pending = computed(() => createRole.isPending.value || updateRole.isPending.value);

const { filter, openGroups, visibleGroups, setAllOpen } = usePermissionGroups(() => props.permissions);
const { grants, changedCount, selectedCount, load, setCell, setRow, setGroup } = useRoleGrants(
  () => props.role,
  () => props.permissions,
  isSuperAdmin
);

/** Edited fields plus permissions whose grants differ from the saved role. */
const changeCount = computed(() => {
  const fields =
    Number(name.value.trim() !== (props.role?.name ?? "")) +
    Number(description.value.trim() !== (props.role?.description ?? ""));
  return fields + changedCount.value;
});
const dirty = computed(() => changeCount.value > 0);

const reset = () => {
  name.value = props.role?.name ?? "";
  description.value = props.role
    ? props.role.description ?? ""
    : props.template
      ? t("rbac.roles.copyName", { name: props.template.description || props.template.name })
      : "";
  load(props.role ?? props.template ?? null);
  submitted.value = false;
};

watch(() => [props.role, props.template, props.permissions] as const, reset, { immediate: true });

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
</script>
