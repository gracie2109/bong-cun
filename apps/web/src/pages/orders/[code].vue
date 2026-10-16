<script setup lang="ts">
import View from "@/views/client/orders/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "order-detail",
  titleKey: "order",
  layout: PAGE_LAYOUT.CLIENT,
  requiresAuth: true,
});
</script>

<template>
  <View />
</template>
