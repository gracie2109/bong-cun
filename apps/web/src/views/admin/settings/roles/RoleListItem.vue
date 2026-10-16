<template>
  <li class="relative">
    <button
      type="button"
      class="w-full rounded-lg border border-l-4 px-3 py-3 pr-10 text-left transition-colors"
      :class="selected ? 'border-primary bg-primary/5' : 'border-l-transparent hover:bg-muted/40'"
      @click="emit('select')"
    >
      <span class="flex items-center gap-2">
        <span class="truncate font-semibold" :class="selected ? 'text-primary' : ''">{{ role.description || role.name }}</span>
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
          <span v-if="holders.length" class="flex -space-x-2">
            <Avatar v-for="member in holders.slice(0, MAX_AVATARS)" :key="member.id" class="size-6 border-2 border-white">
              <AvatarImage v-if="member.photoUrl" :src="member.photoUrl" />
              <AvatarFallback class="bg-primary/10 text-[9px] text-primary">{{ initials(member.name) }}</AvatarFallback>
            </Avatar>
            <span
              v-if="holders.length > MAX_AVATARS"
              class="flex size-6 items-center justify-center rounded-full border-2 border-white bg-muted text-[9px] font-semibold"
            >
              +{{ holders.length - MAX_AVATARS }}
            </span>
          </span>
          {{ $t("rbac.roles.staffCount", { n: role.staffCount }) }}
        </span>
        <span
          v-if="role.name !== CUSTOMER_ROLE"
          class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
          :class="granted === permissionCount && permissionCount > 0
            ? 'bg-primary text-primary-foreground'
            : 'bg-primary/10 text-primary'"
        >
          {{ role.name === SUPER_ADMIN_ROLE
            ? $t("rbac.roles.fullAccess", { n: permissionCount })
            : $t("rbac.roles.grantRatio", { n: granted, total: permissionCount }) }}
        </span>
      </span>
    </button>
    <DropdownMenu v-if="canManage">
      <DropdownMenuTrigger as-child>
        <Button variant="ghost" size="icon" class="absolute right-1.5 top-2 size-8" :aria-label="$t('rbac.roles.more')">
          <EllipsisVertical class="size-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem v-if="role.name !== SUPER_ADMIN_ROLE" @click="emit('clone')">
          <Copy class="mr-2 size-4" />
          {{ $t("rbac.roles.clone") }}
        </DropdownMenuItem>
        <DropdownMenuItem :disabled="role.isSystem" class="text-red-600" @click="emit('remove')">
          <Trash2 class="mr-2 size-4" />
          {{ $t("rbac.roles.delete") }}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  </li>
</template>

<script lang="ts" setup>
import { Copy, EllipsisVertical, Trash2 } from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { Role } from "@/repositories/roles";
import type { StaffMember } from "@/repositories/staff";
import { initials } from "@/views/admin/pets/format";
import { CUSTOMER_ROLE, SUPER_ADMIN_ROLE } from "../rbac";

/** Stacked avatars shown before the "+n" counter. */
const MAX_AVATARS = 3;

defineProps<{
  role: Role;
  selected: boolean;
  /** Staff holding the role. */
  holders: StaffMember[];
  /** Permissions the role holds, out of `permissionCount`. */
  granted: number;
  permissionCount: number;
  canManage: boolean;
}>();

const emit = defineEmits<{ select: []; clone: []; remove: [] }>();
</script>
