<script setup lang="ts">
import View from "@/views/auth/LoginView.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "login",
  titleKey: "login",
  layout: PAGE_LAYOUT.AUTH,
});
</script>

<template>
  <View />
</template>
