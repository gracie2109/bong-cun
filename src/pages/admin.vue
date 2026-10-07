<script setup lang="ts">
import { PAGE_LAYOUT } from "@/lib/constants";

// Child pages inherit this meta (vue-router merges meta from parent to child).
definePageMeta({
  layout: PAGE_LAYOUT.ADMIN,
  requiresAuth: true,
  // Any staff account; each page then needs VIEW on its permission (see auth.global.ts).
  staffOnly: true,
});
</script>

<template>
  <NuxtPage :page-key="(route) => route.fullPath" />
</template>
