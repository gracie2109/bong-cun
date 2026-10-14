<script setup lang="ts">
import { PAGE_LAYOUT } from "@/lib/constants";

// Old link: the profile now lives under /account.
definePageMeta({
  name: "profile",
  titleKey: "profile",
  layout: PAGE_LAYOUT.CLIENT,
  middleware: () => navigateTo({ name: "account-profile" }, { redirectCode: 301 }),
});
</script>

<template>
  <div />
</template>
