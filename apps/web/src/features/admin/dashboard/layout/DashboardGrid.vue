<template>
  <GridLayout
    :layout="entries"
    :col-num="GRID_COLS"
    :row-height="ROW_HEIGHT"
    :margin="[GRID_GAP, GRID_GAP]"
    :is-draggable="editing"
    :is-resizable="editing"
    :use-css-transforms="true"
    :vertical-compact="true"
    @update:layout="onLayout"
  >
    <GridItem
      v-for="entry in entries"
      :key="entry.i"
      :i="entry.i"
      :x="entry.x"
      :y="entry.y"
      :w="entry.w"
      :h="entry.h"
      :min-w="entry.minW"
      :min-h="entry.minH"
      :max-w="entry.maxW"
      :max-h="entry.maxH"
      drag-allow-from=".dashboard-drag-handle"
      drag-ignore-from=".dashboard-no-drag"
    >
      <slot :item="itemOf(entry.i)" />
    </GridItem>
  </GridLayout>
</template>

<script lang="ts" setup>
// The only file that imports the grid library, so it can be swapped for pointer-event code later.
import { computed } from "vue";
import { GridItem, GridLayout } from "grid-layout-plus";
import type { SavedItem } from "@bongcun/core/dashboard";
import { GRID_COLS, GRID_GAP, ROW_HEIGHT } from "./gridConfig";
import { fromGridEntries, toGridEntries, type GridEntry } from "./gridItems";

const props = defineProps<{ items: SavedItem[]; editing?: boolean }>();
const emit = defineEmits<{ "update:items": [items: SavedItem[]] }>();

defineSlots<{ default(props: { item: SavedItem }): unknown }>();

const entries = computed(() => toGridEntries(props.items));
const itemOf = (id: string) => props.items.find((item) => item.id === id) as SavedItem;

const onLayout = (next: GridEntry[]) => {
  const changed = fromGridEntries(props.items, next);
  const same = changed.every((item, index) => {
    const before = props.items[index] as SavedItem;
    return item.x === before.x && item.y === before.y && item.w === before.w && item.h === before.h;
  });
  if (!same) emit("update:items", changed);
};
</script>
