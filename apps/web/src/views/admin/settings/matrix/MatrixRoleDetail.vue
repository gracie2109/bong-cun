<template>
  <aside class="space-y-4 rounded-xl border bg-white p-4 xl:sticky xl:top-4">
    <div class="flex items-center justify-between">
      <h3 class="flex items-center gap-2 font-semibold">
        <IdCard class="size-4 text-primary" />
        {{ $t("rbac.matrix.detail") }}
      </h3>
      <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('rbac.matrix.closeDetail')" @click="emit('close')">
        <X class="size-4" />
      </Button>
    </div>

    <div class="space-y-3 rounded-xl bg-muted/40 p-4">
      <div class="flex items-start gap-3">
        <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground">
          <Crown v-if="role.name === SUPER_ADMIN_ROLE" class="size-5" />
          <UserCog v-else class="size-5" />
        </span>
        <div class="min-w-0">
          <p class="truncate text-lg font-bold">{{ role.description || role.name }}</p>
          <p class="font-mono text-[11px] uppercase text-muted-foreground">{{ $t("rbac.matrix.roleCode") }} {{ role.name }}</p>
        </div>
      </div>
      <p v-if="role.isSystem" class="text-xs text-muted-foreground">
        {{ role.name === SUPER_ADMIN_ROLE ? $t("rbac.roles.superAdminNote") : $t("rbac.roles.systemNote") }}
      </p>
      <div class="grid grid-cols-2 gap-2">
        <div class="rounded-lg border bg-white p-3">
          <p class="text-xs text-muted-foreground">{{ $t("rbac.matrix.granted") }}</p>
          <p class="text-lg font-bold">{{ grantedCount(role, permissions) }} / {{ permissions.length }}</p>
        </div>
        <div class="rounded-lg border bg-white p-3">
          <p class="text-xs text-muted-foreground">{{ $t("rbac.matrix.assigned") }}</p>
          <p class="text-lg font-bold text-primary">{{ $t("rbac.roles.staffCount", { n: role.staffCount }) }}</p>
        </div>
      </div>
    </div>

    <div class="space-y-2">
      <div class="flex items-center justify-between">
        <p class="text-sm font-semibold">{{ $t("rbac.roles.staff", { n: holders.length }) }}</p>
        <router-link :to="{ name: 'settings', query: { role: role.id } }" class="text-xs font-semibold text-primary hover:underline">
          + {{ $t("rbac.roles.assign") }}
        </router-link>
      </div>
      <p v-if="holders.length === 0" class="rounded-lg border border-dashed px-3 py-4 text-center text-xs text-muted-foreground">
        {{ $t("rbac.roles.staffEmpty") }}
      </p>
      <ul v-else class="space-y-1.5">
        <li
          v-for="holder in holders"
          :key="`${holder.staff.id}-${holder.branchId}`"
          class="flex items-center gap-3 rounded-lg border px-3 py-2"
        >
          <Avatar class="size-8">
            <AvatarImage v-if="holder.staff.photoUrl" :src="holder.staff.photoUrl" />
            <AvatarFallback class="bg-primary/10 text-xs text-primary">{{ initials(holder.staff.name) }}</AvatarFallback>
          </Avatar>
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold">{{ holder.staff.name }}</p>
            <p class="truncate text-xs text-muted-foreground">{{ branchName(holder.branchId) }}</p>
          </div>
        </li>
      </ul>
    </div>

    <Button v-if="canManage" class="w-full" as-child>
      <router-link :to="{ name: 'settings', query: { role: role.id } }">
        <SquarePen class="mr-2 size-4" />
        {{ $t("rbac.matrix.editRole") }}
      </router-link>
    </Button>
  </aside>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Crown, IdCard, SquarePen, UserCog, X } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { useBranches } from "@/queries/branches";
import { useStaffList } from "@/queries/staff";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { initials } from "@/views/admin/pets/format";
import { grantedCount, SUPER_ADMIN_ROLE } from "../rbac";

const props = defineProps<{ role: Role; permissions: Permission[]; canManage: boolean }>();
const emit = defineEmits<{ close: [] }>();

const staffQuery = useStaffList();
const branchesQuery = useBranches();

const holders = computed(() =>
  (staffQuery.data.value ?? []).flatMap((member) =>
    member.assignments
      .filter((item) => item.role === props.role.name)
      .map((item) => ({ staff: member, branchId: item.branchId }))
  )
);

const branchName = (id: string): string => {
  const branch = (branchesQuery.data.value ?? []).find((item) => item.id === id);
  return branch ? `${branch.code} · ${branch.name}` : "";
};
</script>
