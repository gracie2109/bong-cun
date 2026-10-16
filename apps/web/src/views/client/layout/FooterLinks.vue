<template>
  <div class="space-y-4">
    <h3 class="text-sm font-semibold text-white">{{ title }}</h3>
    <ul class="space-y-2.5">
      <li v-for="link in links" :key="link.label">
        <RouterLink :to="link.to" class="inline-block py-0.5 transition-colors hover:text-white">{{ link.label }}</RouterLink>
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import type { RouteLocationRaw } from "vue-router";

defineProps<{ title: string; links: { label: string; to: RouteLocationRaw }[] }>();
</script>
