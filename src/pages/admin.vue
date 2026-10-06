<script setup lang="ts">
import { PAGE_LAYOUT } from "@/lib/constants";
import { ADMIN_ROLES } from "@/lib/access";

// Child pages inherit this meta (vue-router merges meta from parent to child).
definePageMeta({
  layout: PAGE_LAYOUT.ADMIN,
  requiresAuth: true,
  roles: ADMIN_ROLES,
});
</script>

<template>
  <NuxtPage :page-key="(route) => route.fullPath" />
</template>
