<template>
  <div class="overflow-hidden rounded-xl border bg-white">
    <div v-if="loading" class="space-y-2 p-4">
      <Skeleton v-for="i in 6" :key="i" class="h-10 w-full" />
    </div>
    <p v-else-if="total === 0" class="px-4 py-10 text-center text-sm text-muted-foreground">
      {{ $t("rbac.roles.noPermissions") }}
    </p>
    <div v-else class="table-scroll">
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
                @click="emit('toggleAll')"
              >
                {{ allCollapsed ? $t("rbac.roles.expandAll") : $t("rbac.roles.collapseAll") }}
              </button>
            </th>
            <th
              v-for="role in roles"
              :key="role.id"
              class="min-w-32 px-3 py-3 text-center align-bottom"
              :class="detailRoleId === role.id ? 'bg-primary/5' : ''"
            >
              <button type="button" class="group flex w-full flex-col items-center gap-1" @click="emit('selectRole', role.id)">
                <span
                  class="flex size-8 items-center justify-center rounded-full"
                  :class="detailRoleId === role.id ? 'bg-primary text-primary-foreground' : 'bg-primary/10 text-primary'"
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
          <template v-for="group in groups" :key="group.key">
            <tr class="border-t bg-primary/5">
              <td :colspan="roles.length + 1" class="px-4 py-2">
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
                  v-for="role in roles"
                  :key="role.id"
                  class="px-3 py-3 text-center"
                  :class="detailRoleId === role.id ? 'bg-primary/5' : ''"
                >
                  <div class="flex flex-col items-center gap-1">
                    <Checkbox
                      :checked="cellState(role, permission)"
                      :disabled="!quickEdit || role.name === SUPER_ADMIN_ROLE"
                      :class="role.name === SUPER_ADMIN_ROLE ? 'border-muted-foreground/40 data-[state=checked]:bg-muted-foreground/40' : ''"
                      :aria-label="`${role.description || role.name}: ${permission.description || permission.name}`"
                      @update:checked="(value: boolean | 'indeterminate') => emit('toggleCell', role, permission, value === true)"
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
          <tr v-if="groups.length === 0">
            <td :colspan="roles.length + 1" class="px-4 py-10 text-center text-muted-foreground">
              {{ $t("rbac.roles.noMatch") }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <MatrixLegend :shown="shown" :total="total" />
  </div>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { ChevronDown, Crown, UserCog } from "lucide-vue-next";
import { Checkbox } from "@/components/ui/checkbox";
import { Skeleton } from "@/components/ui/skeleton";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { moduleIcon, SUPER_ADMIN_ROLE, type Method } from "../rbac";
import MatrixLegend from "./MatrixLegend.vue";
import type { MatrixGroup } from "./useMatrixView";

defineProps<{
  loading: boolean;
  /** Role columns. */
  roles: Role[];
  /** Permission rows, grouped by module and already filtered. */
  groups: MatrixGroup[];
  /** Permissions shown out of `total`. */
  shown: number;
  total: number;
  /** The role open in the side panel, highlighted as a column. */
  detailRoleId: string | undefined;
  quickEdit: boolean;
  allCollapsed: boolean;
  cellState: (role: Role, permission: Permission) => boolean | "indeterminate";
  cellMethods: (role: Role, permission: Permission) => Method[];
}>();

const emit = defineEmits<{
  toggleAll: [];
  selectRole: [roleId: string];
  toggleCell: [role: Role, permission: Permission, on: boolean];
}>();

const collapsed = defineModel<Record<string, boolean>>("collapsed", { required: true });
</script>
