<script setup lang="ts">
import View from "@/features/shop/catalog/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "products",
  titleKey: "products",
  layout: PAGE_LAYOUT.CLIENT,
  keepOnQuery: true,
});
</script>

<template>
  <View />
</template>
