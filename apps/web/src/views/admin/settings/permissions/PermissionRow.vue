<template>
  <tr class="border-t align-top hover:bg-muted/20">
    <td class="px-4 py-4">
      <code class="rounded-md bg-muted px-2 py-1 font-mono text-xs font-semibold">{{ permission.name }}</code>
    </td>
    <td class="max-w-64 px-4 py-4">
      <p class="font-semibold leading-snug">{{ permission.description || permission.name }}</p>
    </td>
    <td class="px-4 py-4">
      <span class="inline-flex items-center gap-1.5 rounded-md bg-primary/10 px-2 py-1 text-xs font-medium text-primary">
        <Icon :icon="moduleIcon(permission.module)" class="size-3.5" />
        {{ permission.module || $t("rbac.ungrouped") }}
      </span>
    </td>
    <td class="px-4 py-4">
      <div class="flex max-w-56 flex-wrap gap-1">
        <span
          v-for="method in methodsOf(permission)"
          :key="method"
          class="flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium"
          :class="method === 'DELETE' ? 'border-red-200 bg-red-50 text-red-700' : 'bg-white text-muted-foreground'"
        >
          <Icon :icon="METHOD_ICONS[method]" class="size-3" />
          {{ $t(`rbac.methods.${method}`) }}
        </span>
      </div>
    </td>
    <td class="px-4 py-4">
      <div class="flex max-w-56 flex-wrap gap-1">
        <router-link
          v-for="role in usedBy"
          :key="role.id"
          :to="{ name: 'settings', query: { role: role.id } }"
          class="rounded-md bg-muted px-2 py-0.5 text-[11px] font-medium hover:bg-primary/10 hover:text-primary"
        >
          {{ role.description || role.name }}
        </router-link>
        <span
          v-if="usedBy.length === 0"
          class="rounded-md bg-amber-50 px-2 py-0.5 text-[11px] font-medium text-amber-700"
        >
          {{ $t("rbac.permissions.unused") }}
        </span>
      </div>
    </td>
    <td class="px-4 py-4 text-right">
      <DropdownMenu v-if="canManage">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('rbac.permissions.col.actions')">
            <EllipsisVertical class="size-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @click="emit('edit', permission)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem class="text-red-600" @click="emit('remove', permission)">
            {{ $t("rbac.roles.remove") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { EllipsisVertical } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { Permission } from "@/repositories/permissions";
import type { Role } from "@/repositories/roles";
import { METHOD_ICONS, methodsOf, moduleIcon } from "../rbac";

defineProps<{
  permission: Permission;
  /** Roles granting any method on this permission. */
  usedBy: Role[];
  canManage: boolean;
}>();

const emit = defineEmits<{ edit: [permission: Permission]; remove: [permission: Permission] }>();
</script>
