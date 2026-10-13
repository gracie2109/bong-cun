<template>
  <nav class="flex flex-wrap gap-1 rounded-xl border bg-white p-1">
    <router-link
      v-for="tab in visibleTabs"
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
import { computed } from "vue";
import { Icon } from "@iconify/vue";
import { useRoute } from "vue-router";
import { useAuthStore } from "@/stores";

const route = useRoute();
const auth = useAuthStore();

// Everything here is read with "shop_orders: VIEW"; the settings form only saves with "ALL".
const tabs = [
  { name: "shopOrders", icon: "lucide:shopping-bag", label: "shop.nav.orders", method: "VIEW" },
  { name: "shopOrderSettings", icon: "lucide:settings-2", label: "shop.nav.settings", method: "VIEW" },
];
const visibleTabs = computed(() => tabs.filter((tab) => auth.can("shop_orders", tab.method)));
</script>
