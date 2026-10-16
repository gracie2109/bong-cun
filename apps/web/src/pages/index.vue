<script setup lang="ts">
import View from "@/views/home/HomeView.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "home",
  titleKey: "home",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
