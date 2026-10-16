<script setup lang="ts">
import View from "@/views/auth/ForgotPassView.vue";
import { PAGE_LAYOUT } from "@/lib/constants";

definePageMeta({
  name: "forgotPw",
  titleKey: "forgotPw",
  layout: PAGE_LAYOUT.AUTH,
});
</script>

<template>
  <View />
</template>
