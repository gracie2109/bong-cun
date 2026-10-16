<template>
  <div class="shop-scroll-row -mx-4 px-4 sm:mx-0 sm:px-0" role="list">
    <button
      v-for="item in items"
      :key="item.id ?? 'all'"
      type="button"
      role="listitem"
      class="h-10 shrink-0 snap-start rounded-full border px-4 text-sm font-medium transition-[background-color,border-color,color] duration-200"
      :class="isActive(item.id) ? 'border-foreground bg-foreground text-white' : 'border-border bg-white hover:border-foreground/40'"
      :aria-pressed="isActive(item.id)"
      @click="emit('select', item.id)"
    >
      {{ item.name }}
    </button>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { CategoryNode } from "@bongcun/core/shop";

const props = defineProps<{ roots: CategoryNode[]; selected: string | null }>();
const emit = defineEmits<{ select: [id: string | null] }>();
const { t } = useI18n();

const items = computed(() => [{ id: null, name: t("client.catalog.allShort") }, ...props.roots.map((root) => ({ id: root.id, name: root.name }))]);

// A sub-category keeps its parent's pill lit.
const isActive = (id: string | null) => {
  if (id === null) return props.selected === null;
  if (props.selected === id) return true;
  return props.roots.find((root) => root.id === id)?.children.some((child) => child.id === props.selected) ?? false;
};
</script>
