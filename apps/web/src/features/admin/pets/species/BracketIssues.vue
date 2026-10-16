<template>
  <ul class="space-y-1">
    <li
      v-for="issue in issues"
      :key="issue.text"
      class="flex items-start gap-2 rounded-lg px-3 py-2 text-sm"
      :class="issue.blocking ? 'bg-red-50 text-red-700' : 'bg-amber-50 text-amber-700'"
    >
      <TriangleAlert class="mt-0.5 size-4 shrink-0" />
      {{ issue.text }}
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { TriangleAlert } from "lucide-vue-next";

defineProps<{
  /** Problems with the brackets; a blocking one stops saving, the rest only warn. */
  issues: { blocking: boolean; text: string }[];
}>();
</script>
