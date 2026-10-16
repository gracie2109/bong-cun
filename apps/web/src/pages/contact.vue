<script setup lang="ts">
import View from "@/features/shop/contact/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "contact",
  titleKey: "contact",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
