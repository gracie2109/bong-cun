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

// Screens for managers need "attendance: VIEW"; later steps add the other tabs here.
const tabs = [
  { name: "attendanceRoster", icon: "lucide:calendar-range", label: "attendance.nav.roster", method: "VIEW" },
  { name: "attendanceSettings", icon: "lucide:settings-2", label: "attendance.nav.settings", method: "VIEW" },
];
const visibleTabs = computed(() => tabs.filter((tab) => auth.can("attendance", tab.method)));
</script>
