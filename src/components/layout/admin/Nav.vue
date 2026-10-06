<template>
  <SidebarMenuItem v-for="item in props.items" :key="item.title">
    <Collapsible as-child v-if="item.children" class="group/collapsible">
      <CollapsibleTrigger as-child>
        <SidebarMenuButton :tooltip="item.title">
          <Icon
            :icon="item.icon || 'lucide:dot'"
            :class="
              clsx({ 'text-primary': route.fullPath?.includes(item.name) })
            "
          />
          <span
            class="font-semibold capitalize"
            :class="
              clsx({ 'text-primary': route.fullPath?.includes(item.name) })
            "
          >
            {{ item.title }}
          </span>
          <ChevronRight
            class="ml-auto transition-transform duration-200 group-data-[state=open]/collapsible:rotate-90"
          />
        </SidebarMenuButton>
      </CollapsibleTrigger>
      <CollapsibleContent class="ml-4 space-y-1 my-2">
        <Nav :items="item.children" />
      </CollapsibleContent>
    </Collapsible>
    <template v-else>
      <SidebarMenuSubButton as-child>
        <router-link
          :to="{ name: item.name }"
          class="pl-2 hover:text-primary-subb"
        >
          <Icon
            :icon="item.icon || 'lucide:dot'"
            class="size-4"
            :class="{
              'text-primary': route.name?.toString() === item.name,
            }"
          />
          <span
            class="font-semibold capitalize"
            :class="{
              'text-primary': route.name?.toString() === item.name,
            }"
          >
            {{ item.title }}
          </span>
        </router-link>
      </SidebarMenuSubButton>
    </template>
  </SidebarMenuItem>
</template>

<script lang="ts" setup>
import { useRoute } from "vue-router";
import { Icon } from "@iconify/vue";
import clsx from "clsx";
import { ChevronRight } from "lucide-vue-next";
import type { LinkProp } from "@/types";
import {
  SidebarMenuItem,
  SidebarMenuButton,
  SidebarMenuSubButton,
} from "@/components/ui/sidebar";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";

const route = useRoute();
const props = defineProps<{ items: LinkProp[] }>();
</script>
