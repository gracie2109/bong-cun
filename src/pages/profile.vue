<script setup lang="ts">
import View from "@/views/client/profile/Index.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "profile",
  titleKey: "profile",
  layout: PAGE_LAYOUT.CLIENT,
});
</script>

<template>
  <View />
</template>
