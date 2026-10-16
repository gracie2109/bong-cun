<template>
  <ul class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <li v-for="(combo, index) in combos" :key="combo.id" class="shop-reveal" :style="{ '--i': revealIndex(index) }">
      <ComboCard :combo="combo" />
    </li>
  </ul>
</template>

<script lang="ts" setup>
import ComboCard from "@/components/shop/spa/ComboCard.vue";
import type { SpaCombo } from "@bongcun/core/spa";
import { revealIndex } from "@/utils/shop/motion";

defineProps<{ combos: SpaCombo[] }>();
</script>
