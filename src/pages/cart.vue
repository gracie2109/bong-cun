<script setup lang="ts">
import View from "@/views/client/cart/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "cart",
  titleKey: "cart",
  layout: PAGE_LAYOUT.NO_LAYOUT,
});
</script>

<template>
  <View />
</template>
