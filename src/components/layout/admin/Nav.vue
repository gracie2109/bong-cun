<template>
  <SidebarMenuItem v-for="item in items" :key="item.name">
    <SidebarMenuButton
      as-child
      :tooltip="$t(item.title)"
      :is-active="isActive(item.name)"
      class="h-10 gap-3 rounded-lg px-3 font-medium text-sidebar-foreground transition-colors hover:bg-muted data-[active=true]:bg-sidebar-accent data-[active=true]:font-semibold data-[active=true]:text-sidebar-accent-foreground"
    >
      <router-link :to="{ name: item.name }">
        <Icon :icon="item.icon || 'lucide:dot'" class="size-[18px] shrink-0" />
        <span class="truncate">{{ $t(item.title) }}</span>
        <span
          v-if="badges?.[item.name]"
          class="ml-auto rounded-full bg-red-600 px-1.5 text-[10px] font-bold leading-4 text-white group-data-[collapsible=icon]:hidden"
        >
          {{ badges[item.name] }}
        </span>
      </router-link>
    </SidebarMenuButton>
  </SidebarMenuItem>
</template>

<script lang="ts" setup>
import { useRoute } from "vue-router";
import { Icon } from "@iconify/vue";
import type { LinkProp } from "@/types";
import { SidebarMenuButton, SidebarMenuItem } from "@/components/ui/sidebar";

/** `badges`: a number to show on the item with that route name (orders waiting, for example). */
defineProps<{ items: LinkProp[]; badges?: Record<string, number> }>();

// Detail pages light up the list they belong to.
const PARENT_ROUTE: Record<string, string> = {
  petDetail: "pets",
  usersGroup: "users",
};

const route = useRoute();

const isActive = (name: string): boolean => {
  const current = route.name?.toString() ?? "";
  return current === name || PARENT_ROUTE[current] === name;
};
</script>
