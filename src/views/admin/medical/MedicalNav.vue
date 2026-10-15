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

// Everything is read with "medical: VIEW"; the catalogs and rules are changed with "SETTING".
const tabs = [
  { name: "medicalQueue", icon: "lucide:stethoscope", label: "medical.nav.queue", method: "VIEW" },
  { name: "medicalVisits", icon: "lucide:list-checks", label: "medical.nav.visits", method: "VIEW" },
  { name: "medicalReminders", icon: "lucide:bell-ring", label: "medical.nav.reminders", method: "VIEW" },
  { name: "medicalSettings", icon: "lucide:settings-2", label: "medical.nav.settings", method: "VIEW" },
];
const visibleTabs = computed(() => tabs.filter((tab) => auth.can("medical", tab.method)));
</script>
