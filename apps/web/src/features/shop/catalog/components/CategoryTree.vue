<template>
  <ul class="space-y-0.5">
    <li>
      <FilterOption :active="!selected" @click="emit('select', null)">{{ $t("client.catalog.allCategories") }}</FilterOption>
    </li>
    <li v-for="root in tree" :key="root.id">
      <FilterOption :active="selected === root.id" @click="emit('select', root.id)">{{ root.name }}</FilterOption>
      <ul v-if="root.children.length > 0 && isOpen(root)" class="mb-1 ml-3 space-y-0.5 border-l pl-2">
        <li v-for="child in root.children" :key="child.id">
          <FilterOption small :active="selected === child.id" @click="emit('select', child.id)">{{ child.name }}</FilterOption>
        </li>
      </ul>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import type { CategoryNode } from "@bongcun/core/shop";
import FilterOption from "./FilterOption.vue";

const props = defineProps<{ tree: CategoryNode[]; selected: string | null }>();
const emit = defineEmits<{ select: [id: string | null] }>();

// Sub-categories show under the chosen category only, so the list stays short.
const isOpen = (root: CategoryNode) =>
  props.selected === root.id || root.children.some((child) => child.id === props.selected);
</script>
