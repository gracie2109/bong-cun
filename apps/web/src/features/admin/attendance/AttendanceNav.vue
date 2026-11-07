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

// Screens for managers need "attendance: VIEW"; "mine" is for every staff member (no method).
const tabs = [
  { name: "attendanceToday", icon: "lucide:clipboard-check", label: "attendance.nav.today", method: "VIEW" },
  { name: "attendanceRoster", icon: "lucide:calendar-range", label: "attendance.nav.roster", method: "VIEW" },
  { name: "attendanceRequests", icon: "lucide:clipboard-check", label: "attendance.nav.requests", method: "VIEW" },
  { name: "attendanceLeave", icon: "lucide:calendar-off", label: "attendance.nav.leave", method: "VIEW" },
  { name: "attendanceTimesheet", icon: "lucide:table-properties", label: "attendance.nav.timesheet", method: "VIEW" },
  { name: "attendanceHistory", icon: "lucide:history", label: "attendance.nav.history", method: "VIEW" },
  { name: "attendanceSettings", icon: "lucide:settings-2", label: "attendance.nav.settings", method: "VIEW" },
  { name: "attendanceRegister", icon: "lucide:calendar-plus", label: "attendance.nav.register", method: null },
  { name: "attendanceMe", icon: "lucide:user-round", label: "attendance.nav.me", method: null },
];
const visibleTabs = computed(() => tabs.filter((tab) => tab.method === null || auth.can("attendance", tab.method)));
</script>
