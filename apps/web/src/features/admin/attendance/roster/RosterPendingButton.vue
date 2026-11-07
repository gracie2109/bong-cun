<template>
  <router-link
    v-if="count > 0"
    :to="{ name: 'attendanceRequests' }"
    class="inline-flex min-h-10 items-center gap-2 rounded-lg border border-amber-300 bg-amber-50 px-3 text-sm font-semibold text-amber-900 hover:bg-amber-100"
  >
    <ClipboardCheck class="size-4" />
    {{ $t("attendance.roster.pendingRequests", { count }) }}
  </router-link>
</template>

<script lang="ts" setup>
import { ClipboardCheck } from "lucide-vue-next";

defineProps<{ count: number }>();
</script>
