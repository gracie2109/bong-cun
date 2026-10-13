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

// Everything here is read with "schedule: VIEW"; changing the tables, hours and staff needs "SETTING".
const tabs = [
  { name: "spaBoard", icon: "lucide:calendar-days", label: "spa.nav.board", method: "VIEW" },
  { name: "spaAppointments", icon: "lucide:list-checks", label: "spa.nav.appointments", method: "VIEW" },
  { name: "spaSettings", icon: "lucide:settings-2", label: "spa.nav.settings", method: "SETTING" },
  { name: "listOrderSchedule", icon: "lucide:globe", label: "spa.nav.webRequests", method: "VIEW" },
];
const visibleTabs = computed(() => tabs.filter((tab) => auth.can("schedule", tab.method)));
</script>
