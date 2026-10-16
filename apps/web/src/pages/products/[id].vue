<script setup lang="ts">
import View from "@/features/shop/product/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "product-detail",
  titleKey: "productDetail",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
