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
        <div class="flex gap-2">
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
          <Input id="role-desc" v-model="description" :placeholder="$t('rbac.roles.descPlaceholder')" />
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
          @click="staffSection?.scrollIntoView({ behavior: 'smooth' })"
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

      <Collapsible
        v-for="group in visibleGroups"
        :key="group.key"
        :open="openGroups[group.key] ?? true"
        class="overflow-hidden rounded-xl border"
        @update:open="(value: boolean) => (openGroups[group.key] = value)"
      >
        <div class="flex items-center gap-3 bg-muted/30 px-4 py-3">
          <CollapsibleTrigger as-child>
            <button type="button" class="flex min-w-0 flex-1 items-center gap-3 text-left">
              <ChevronDown
                class="size-4 shrink-0 text-muted-foreground transition-transform"
                :class="(openGroups[group.key] ?? true) ? '' : '-rotate-90'"
              />
              <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <Icon :icon="moduleIcon(group.module)" class="size-4" />
              </span>
              <span class="truncate font-semibold">{{ group.module ?? $t("rbac.ungrouped") }}</span>
              <span
                class="shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold"
                :class="groupState(group.items) === true ? 'bg-emerald-50 text-emerald-700' : 'bg-muted text-muted-foreground'"
              >
                {{ $t("rbac.roles.moduleCount", { n: groupGranted(group.items), total: group.items.length }) }}
              </span>
            </button>
          </CollapsibleTrigger>
          <label class="flex shrink-0 items-center gap-2 text-xs font-medium text-muted-foreground">
            {{ groupState(group.items) === "indeterminate" ? $t("rbac.roles.partial") : $t("rbac.roles.selectAll") }}
            <Checkbox
              :checked="groupState(group.items)"
              :disabled="isSuperAdmin"
              @update:checked="(value: boolean | 'indeterminate') => setGroup(group.items, value === true)"
            />
          </label>
        </div>

        <CollapsibleContent>
          <div class="grid gap-3 p-4 md:grid-cols-2">
            <div
              v-for="permission in group.items"
              :key="permission.id"
              class="flex gap-3 rounded-lg border p-3 transition-colors"
              :class="rowState(permission) === false ? 'bg-white' : 'border-primary/30 bg-primary/5'"
            >
              <Checkbox
                class="mt-0.5"
                :checked="rowState(permission)"
                :disabled="isSuperAdmin"
                :aria-label="permission.description || permission.name"
                @update:checked="(value: boolean | 'indeterminate') => setRow(permission, value === true)"
              />
              <div class="min-w-0 flex-1 space-y-2">
                <div>
                  <p class="text-sm font-semibold leading-snug">{{ permission.description || permission.name }}</p>
                  <p class="font-mono text-[11px] text-muted-foreground">{{ permission.name }}</p>
                </div>
                <div class="flex flex-wrap gap-1">
                  <button
                    v-for="method in methodsOf(permission)"
                    :key="method"
                    type="button"
                    :aria-pressed="isSuperAdmin || has(permission.id, method)"
                    :disabled="isSuperAdmin"
                    class="flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium transition-colors disabled:cursor-not-allowed"
                    :class="isSuperAdmin || has(permission.id, method)
                      ? 'border-primary bg-primary text-primary-foreground'
                      : 'border-dashed text-muted-foreground hover:border-primary hover:text-primary'"
                    @click="setCell(permission.id, method, !has(permission.id, method))"
                  >
                    <Icon :icon="METHOD_ICONS[method]" class="size-3" />
                    {{ $t(`rbac.methods.${method}`) }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </CollapsibleContent>
      </Collapsible>
    </section>

    <section v-if="role && role.name !== CUSTOMER_ROLE" ref="staffSection" class="rounded-xl border bg-white">
      <div class="flex items-center justify-between gap-3 border-b px-5 py-3">
        <h4 class="font-semibold">{{ $t("rbac.roles.staff", { n: holders.length }) }}</h4>
        <Button type="button" variant="ghost" size="sm" class="text-primary" @click="assignOpen = true">
          <UserPlus class="mr-2 size-4" />
          {{ $t("rbac.roles.assign") }}
        </Button>
      </div>
      <p v-if="holders.length === 0" class="px-5 py-6 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.staffEmpty") }}
      </p>
      <ul v-else class="grid gap-2 p-3 sm:grid-cols-2">
        <li
          v-for="holder in holders"
          :key="`${holder.staff.id}-${holder.branchId}`"
          class="flex items-center gap-3 rounded-lg border px-3 py-2"
        >
          <Avatar class="size-9">
            <AvatarImage v-if="holder.staff.photoUrl" :src="holder.staff.photoUrl" />
            <AvatarFallback class="bg-primary/10 text-xs text-primary">{{ initials(holder.staff.name) }}</AvatarFallback>
          </Avatar>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-semibold">{{ holder.staff.name }}</p>
            <p class="truncate text-xs text-muted-foreground">{{ branchName(holder.branchId) }}</p>
          </div>
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

    <Transition
      enter-from-class="translate-y-4 opacity-0"
      leave-to-class="translate-y-4 opacity-0"
      enter-active-class="transition duration-200"
      leave-active-class="transition duration-150"
    >
      <div
        v-if="role && dirty"
        class="sticky bottom-4 z-20 flex flex-wrap items-center justify-between gap-3 rounded-xl border bg-white px-4 py-3 shadow-lg"
      >
        <p class="flex items-center gap-2 text-sm">
          <span class="flex size-8 items-center justify-center rounded-lg bg-amber-50 text-amber-600">
            <ClipboardPen class="size-4" />
          </span>
          <b>{{ $t("rbac.roles.unsavedCount", { n: changeCount }) }}</b>
          <span class="text-muted-foreground">{{ $t("rbac.roles.unsavedOn", { name: role.description || role.name }) }}</span>
        </p>
        <div class="flex gap-2">
          <Button type="button" variant="ghost" :disabled="pending" @click="reset">{{ $t("rbac.roles.discard") }}</Button>
          <Button type="button" :disabled="pending" @click="save">
            <Check class="mr-2 size-4" />
            {{ $t("rbac.roles.savePermissions") }}
          </Button>
        </div>
      </div>
    </Transition>

    <AssignStaffSheet
      v-if="role"
      v-model:open="assignOpen"
      :role="role.name"
      :staff="staff"
      :branches="branches"
      :roles="roles"
    />
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Icon } from "@iconify/vue";
import {
  CalendarDays,
  Check,
  ChevronDown,
  ChevronsDownUp,
  ChevronsUpDown,
  ClipboardPen,
  Filter,
  Lock,
  RotateCcw,
  UserCog,
  UserPlus,
  Users,
} from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useCreateRole, useUpdateRole } from "@/queries/roles";
import { useSaveStaffAssignments } from "@/queries/staff";
import type { Branch } from "@/repositories/branches";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import type { StaffMember } from "@/repositories/staff";
import { formatDate, initials } from "@/views/admin/pets/format";
import AssignStaffSheet from "./AssignStaffSheet.vue";
import {
  CUSTOMER_ROLE,
  fold,
  grantedMethods,
  groupByModule,
  METHOD_ICONS,
  METHODS,
  methodsOf,
  moduleIcon,
  ROLE_CODE_PATTERN,
  SUPER_ADMIN_ROLE,
  type Method,
} from "../rbac";

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
const saveStaff = useSaveStaffAssignments();

const name = ref("");
const description = ref("");
const grants = ref<Record<string, Method[]>>({});
const submitted = ref(false);
const assignOpen = ref(false);
const filter = ref("");
const openGroups = ref<Record<string, boolean>>({});
const staffSection = ref<HTMLElement | null>(null);

const isSuperAdmin = computed(() => props.role?.name === SUPER_ADMIN_ROLE);
const nameValid = computed(() => ROLE_CODE_PATTERN.test(name.value.trim()));
const pending = computed(() => createRole.isPending.value || updateRole.isPending.value);

const groups = computed(() =>
  groupByModule(props.permissions).map((group) => ({ ...group, key: group.module ?? "_" }))
);
const visibleGroups = computed(() => {
  const text = fold(filter.value);
  if (!text) return groups.value;
  return groups.value
    .map((group) => ({
      ...group,
      items: group.items.filter((item) =>
        fold(`${item.name} ${item.description ?? ""} ${group.module ?? ""}`).includes(text)
      ),
    }))
    .filter((group) => group.items.length > 0);
});

const setAllOpen = (open: boolean) => {
  openGroups.value = Object.fromEntries(groups.value.map((group) => [group.key, open]));
};

const grantsOf = (role: Role | null): Record<string, Method[]> =>
  Object.fromEntries(
    props.permissions
      .map((permission) => [permission.id, role ? grantedMethods(role.permissions, permission) : []] as const)
      .filter(([, methods]) => methods.length > 0)
  );

const initialGrants = computed(() => grantsOf(props.role));

const sameMethods = (a: readonly Method[] = [], b: readonly Method[] = []): boolean =>
  a.length === b.length && a.every((method) => b.includes(method));

/** Permissions whose grants differ from the saved role, plus each edited field. */
const changeCount = computed(() => {
  const fields = Number(name.value.trim() !== (props.role?.name ?? "")) +
    Number(description.value.trim() !== (props.role?.description ?? ""));
  const changed = props.permissions.filter(
    (permission) => !sameMethods(grants.value[permission.id], initialGrants.value[permission.id])
  ).length;
  return fields + changed;
});
const dirty = computed(() => changeCount.value > 0);

const reset = () => {
  const source = props.role ?? props.template ?? null;
  name.value = props.role?.name ?? "";
  description.value = props.role
    ? props.role.description ?? ""
    : props.template
      ? t("rbac.roles.copyName", { name: props.template.description || props.template.name })
      : "";
  grants.value = grantsOf(source);
  submitted.value = false;
};

watch(() => [props.role, props.template, props.permissions] as const, reset, { immediate: true });

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

const groupGranted = (items: Permission[]): number => items.filter((item) => rowState(item) !== false).length;

const groupState = (items: Permission[]): boolean | "indeterminate" => {
  const states = items.map(rowState);
  if (states.every((state) => state === true)) return true;
  return states.every((state) => state === false) ? false : "indeterminate";
};

const setGroup = (items: Permission[], on: boolean) => {
  for (const permission of items) setRow(permission, on);
};

const selectedCount = computed(() => groupGranted(props.permissions));

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

const holders = computed(() =>
  props.staff.flatMap((member) =>
    member.assignments
      .filter((item) => item.role === props.role?.name)
      .map((item) => ({ staff: member, branchId: item.branchId }))
  )
);

const branchName = (id: string): string => {
  const branch = props.branches.find((item) => item.id === id);
  return branch ? `${branch.code} · ${branch.name}` : "";
};

const removeHolder = (member: StaffMember, branchId: string) =>
  saveStaff.mutate({
    userId: member.id,
    assignments: member.assignments.filter((item) => item.branchId !== branchId),
  });
</script>
