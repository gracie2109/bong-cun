<script setup lang="ts">
import View from "@/views/client/about/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "about-us",
  titleKey: "about-us",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
