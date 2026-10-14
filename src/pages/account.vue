<script setup lang="ts">
import AccountShell from "@/views/client/account/AccountShell.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

// Child pages inherit this meta (vue-router merges meta from parent to child).
definePageMeta({
  name: "account-shell",
  layout: PAGE_LAYOUT.CLIENT,
  requiresAuth: true,
});
</script>

<template>
  <AccountShell>
    <NuxtPage />
  </AccountShell>
</template>
