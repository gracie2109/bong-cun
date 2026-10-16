<script setup lang="ts">
import View from "@/views/client/boarding/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "boarding",
  titleKey: "boarding",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
