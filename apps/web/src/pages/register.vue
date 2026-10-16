<script setup lang="ts">
import View from "@/views/auth/RegisterView.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "register",
  titleKey: "register",
  layout: PAGE_LAYOUT.AUTH,
});
</script>

<template>
  <View />
</template>
