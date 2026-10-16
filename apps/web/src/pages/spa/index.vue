<script setup lang="ts">
import View from "@/views/client/spa/catalog/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "spa",
  titleKey: "spa",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
