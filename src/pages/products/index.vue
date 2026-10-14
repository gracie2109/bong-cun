<script setup lang="ts">
import View from "@/views/client/catalog/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "products",
  titleKey: "products",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
