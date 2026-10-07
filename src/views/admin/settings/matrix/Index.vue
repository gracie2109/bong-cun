<template>
  <RbacLayout>
    <div class="flex flex-wrap items-center justify-between gap-3 rounded-xl border bg-white p-3">
      <p class="text-sm text-muted-foreground">{{ $t("rbac.matrix.hint") }}</p>
      <Select v-model="methodFilter">
        <SelectTrigger class="w-48" :aria-label="$t('rbac.matrix.method')">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">{{ $t("rbac.matrix.allMethods") }}</SelectItem>
          <SelectItem v-for="method in METHODS" :key="method" :value="method">{{ $t(`rbac.methods.${method}`) }}</SelectItem>
        </SelectContent>
      </Select>
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
            <tr class="text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="sticky left-0 z-10 min-w-56 bg-white px-4 py-3 text-left font-semibold">
                {{ $t("rbac.roles.permission") }}
              </th>
              <th v-for="role in staffRoles" :key="role.id" class="min-w-32 px-3 py-3 text-center font-semibold">
                <router-link :to="{ name: 'settings', query: { role: role.id } }" class="hover:text-primary hover:underline">
                  {{ role.description || role.name }}
                </router-link>
                <p class="font-mono text-[10px] normal-case tracking-normal text-muted-foreground/70">{{ role.name }}</p>
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="group in groups" :key="group.module ?? '_'">
              <tr class="border-t bg-muted/30">
                <td
                  :colspan="staffRoles.length + 1"
                  class="sticky left-0 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-primary"
                >
                  {{ group.module ?? $t("rbac.ungrouped") }}
                </td>
              </tr>
              <tr v-for="permission in group.items" :key="permission.id" class="border-t hover:bg-muted/20">
                <td class="sticky left-0 z-10 bg-white px-4 py-2.5">
                  <p class="font-medium">{{ permission.description || permission.name }}</p>
                  <p class="font-mono text-[11px] text-muted-foreground">{{ permission.name }}</p>
                </td>
                <td v-for="role in staffRoles" :key="role.id" class="px-3 py-2.5 text-center">
                  <template v-if="methodFilter === ALL">
                    <span
                      v-if="cell(role, permission).state === 'full'"
                      class="inline-flex items-center gap-1 rounded-full bg-primary px-2 py-0.5 text-[11px] font-semibold text-primary-foreground"
                    >
                      <Check class="size-3" />
                      {{ $t("rbac.matrix.full") }}
                    </span>
                    <div v-else-if="cell(role, permission).state === 'partial'" class="flex flex-wrap justify-center gap-1">
                      <span
                        v-for="method in cell(role, permission).methods"
                        :key="method"
                        class="rounded-full bg-primary/10 px-1.5 py-0.5 text-[10px] font-medium text-primary"
                      >
                        {{ $t(`rbac.methods.${method}`) }}
                      </span>
                    </div>
                    <span v-else class="text-muted-foreground/50">{{ $t("rbac.matrix.none") }}</span>
                  </template>
                  <template v-else>
                    <span v-if="!methodsOf(permission).includes(methodFilter as Method)" class="text-muted-foreground/30">·</span>
                    <Check
                      v-else-if="cell(role, permission).methods.includes(methodFilter as Method)"
                      class="mx-auto size-4 text-primary"
                    />
                    <span v-else class="text-muted-foreground/50">{{ $t("rbac.matrix.none") }}</span>
                  </template>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-4 text-xs text-muted-foreground">
      <span class="flex items-center gap-1.5">
        <span class="inline-block size-3 rounded-full bg-primary" /> {{ $t("rbac.matrix.legendFull") }}
      </span>
      <span class="flex items-center gap-1.5">
        <span class="inline-block size-3 rounded-full bg-primary/20" /> {{ $t("rbac.matrix.legendPartial") }}
      </span>
      <span class="flex items-center gap-1.5">{{ $t("rbac.matrix.none") }} {{ $t("rbac.matrix.legendNone") }}</span>
    </div>
  </RbacLayout>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Check } from "lucide-vue-next";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import RbacLayout from "../RbacLayout.vue";
import { grantedMethods, groupByModule, METHODS, methodsOf, type Method } from "../rbac";

const ALL = "all";
const SUPER_ADMIN_ROLE = "superAdmin";
const CUSTOMER_ROLE = "customer";

const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const rolesQuery = useRolesList();
// Customers never hold staff permissions, so they have no column.
const staffRoles = computed(() => (rolesQuery.data.value ?? []).filter((role) => role.name !== CUSTOMER_ROLE));
const loading = computed(() => permissionsQuery.isPending.value || rolesQuery.isPending.value);

const methodFilter = ref<string>(ALL);
const groups = computed(() => groupByModule(permissions.value));

type Cell = { state: "full" | "partial" | "none"; methods: Method[] };

const cell = (role: Role, permission: Permission): Cell => {
  const offered = methodsOf(permission);
  // superAdmin passes every check in has_permission() whatever it is granted.
  const methods = role.name === SUPER_ADMIN_ROLE ? offered : grantedMethods(role.permissions, permission);
  if (methods.length === 0) return { state: "none", methods };
  return { state: methods.length === offered.length ? "full" : "partial", methods };
};
</script>
