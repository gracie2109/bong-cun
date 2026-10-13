<template>
  <nav class="flex flex-wrap gap-1 rounded-xl border bg-white p-1">
    <router-link
      v-for="tab in visibleTabs"
      :key="tab.name"
      :to="{ name: tab.name, query: filterQuery(route.query) }"
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
import { filterQuery } from "./shared/useReportFilters";

const route = useRoute();
const auth = useAuthStore();

// Every tab needs "reports: VIEW"; the filter in the URL query moves with the tab.
const tabs = [
  { name: "reportsOverview", icon: "lucide:chart-column", label: "reports.nav.overview" },
  { name: "reportsItems", icon: "lucide:package-search", label: "reports.nav.items" },
  { name: "reportsStaff", icon: "lucide:users", label: "reports.nav.staff" },
];
const visibleTabs = computed(() => (auth.can("reports", "VIEW") ? tabs : []));
</script>
