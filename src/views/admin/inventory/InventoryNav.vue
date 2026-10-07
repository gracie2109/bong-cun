<template>
  <nav class="flex flex-wrap gap-1 rounded-xl border bg-white p-1">
    <router-link
      v-for="tab in TABS"
      :key="tab.name"
      :to="{ name: tab.name }"
      class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
      :class="route.name === tab.name ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
    >
      <Icon :icon="tab.icon" class="size-4" />
      {{ $t(tab.label) }}
    </router-link>
  </nav>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { useRoute } from "vue-router";

const route = useRoute();

// Every tab needs "inventory: VIEW", the same grant that opens this menu.
const TABS = [
  { name: "inventoryStock", icon: "lucide:boxes", label: "adminNav.stock" },
  { name: "stockDocuments", icon: "lucide:clipboard-list", label: "adminNav.stockDocuments" },
  { name: "suppliers", icon: "lucide:truck", label: "adminNav.suppliers" },
];
</script>
