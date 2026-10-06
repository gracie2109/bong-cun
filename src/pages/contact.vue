<script setup lang="ts">
import View from "@/views/client/contact/ContactView.vue";
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
