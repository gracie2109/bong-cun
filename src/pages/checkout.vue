<script setup lang="ts">
import View from "@/views/client/checkout/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "checkout",
  titleKey: "checkout",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
