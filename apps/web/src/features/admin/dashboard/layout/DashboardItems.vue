<template>
  <DashboardGrid v-if="wide" :items="displayItems" :editing="editing" @update:items="emit('update:items', $event)">
    <template #default="{ item }">
      <slot :item="item" />
    </template>
  </DashboardGrid>
  <StackedList v-else :items="displayItems">
    <template #default="{ item }">
      <slot :item="item" />
    </template>
  </StackedList>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useMediaQuery } from "@vueuse/core";
import type { SavedItem } from "@bongcun/core/dashboard";
import { STACK_BELOW } from "./gridConfig";
import DashboardGrid from "./DashboardGrid.vue";
import StackedList from "./StackedList.vue";
import { toDisplayItems } from "./layoutCodec";

const props = defineProps<{ items: SavedItem[]; editing?: boolean }>();
const emit = defineEmits<{ "update:items": [items: SavedItem[]] }>();
defineSlots<{ default(props: { item: SavedItem }): unknown }>();

const wide = useMediaQuery(`(min-width: ${STACK_BELOW}px)`);
// Drawn sizes are kept inside the limits and pulled up; saving is a separate, explicit action.
const displayItems = computed(() => toDisplayItems(props.items));
</script>
