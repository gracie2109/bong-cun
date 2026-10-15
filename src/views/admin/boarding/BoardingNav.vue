<template>
  <nav class="flex flex-wrap gap-1 rounded-xl border bg-white p-1">
    <router-link
      v-for="tab in visibleTabs"
      :key="tab.name"
      :to="{ name: tab.name }"
      class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
      :class="isActive(tab.name) ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
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

// Everything is read with "boarding: VIEW"; kennels, prices and rules are changed with "SETTING".
const tabs = [
  { name: "boardingBoard", icon: "lucide:home", label: "boarding.nav.board", method: "VIEW" },
  { name: "boardingStays", icon: "lucide:list-checks", label: "boarding.nav.stays", method: "VIEW" },
  { name: "boardingSettings", icon: "lucide:settings-2", label: "boarding.nav.settings", method: "VIEW" },
];
// A stay's detail page belongs to the stays tab.
const isActive = (name: string): boolean => route.name === name || (name === "boardingStays" && route.name === "boardingStayDetail");
const visibleTabs = computed(() => tabs.filter((tab) => auth.can("boarding", tab.method)));
</script>
