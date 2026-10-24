<template>
  <div class="space-y-3">
    <div v-for="item in ordered" :key="item.id">
      <slot :item="item" />
    </div>
  </div>
</template>

<script lang="ts" setup>
// Below the grid breakpoint every widget takes the full width, in reading order.
import { computed } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";
import { stackOrder } from "./layoutMath";

const props = defineProps<{ items: SavedItem[] }>();
defineSlots<{ default(props: { item: SavedItem }): unknown }>();

const ordered = computed(() => stackOrder(props.items));
</script>
