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
      </router-link>
    </SidebarMenuButton>
  </SidebarMenuItem>
</template>

<script lang="ts" setup>
import { useRoute } from "vue-router";
import { Icon } from "@iconify/vue";
import type { LinkProp } from "@/types";
import { SidebarMenuButton, SidebarMenuItem } from "@/components/ui/sidebar";

defineProps<{ items: LinkProp[] }>();

// Detail pages light up the list they belong to.
const PARENT_ROUTE: Record<string, string> = {
  petDetail: "pets",
  detailOrderScheduleDetail: "listOrderSchedule",
  usersGroup: "users",
};

const route = useRoute();

const isActive = (name: string): boolean => {
  const current = route.name?.toString() ?? "";
  return current === name || PARENT_ROUTE[current] === name;
};
</script>
