<script setup lang="ts">
import View from "@/features/shop/spa/booking/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "spa-book",
  titleKey: "spaBook",
  layout: PAGE_LAYOUT.CLIENT,
  requiresAuth: true,
});
</script>

<template>
  <View />
</template>
