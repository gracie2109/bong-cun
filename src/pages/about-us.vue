<script setup lang="ts">
import View from "@/views/home/HomeView.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "about-us",
  titleKey: "about-us",
  layout: PAGE_LAYOUT.CLIENT,
  // Placeholder: renders the home page until this page gets its own content.
  noindex: true,
});
</script>

<template>
  <View />
</template>
