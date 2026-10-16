<template>
  <div class="flex flex-wrap items-center gap-2 rounded-xl border bg-white p-3">
    <slot name="search">
      <SearchInput v-if="showSearch" v-model="search" :placeholder="placeholder" @submit="emit('apply')" />
      <div v-else class="flex-1" />
    </slot>
    <slot name="quick" />
    <div class="flex items-center gap-2">
      <slot name="buttons">
        <ClearFilterButton v-if="showClear" :disabled="!search && !activeCount" @click="emit('clear')" />
        <FilterButton
          v-if="hasFilter"
          :active-count="activeCount"
          :width="filterWidth"
          @open="emit('open-filters')"
          @apply="emit('apply')"
          @reset="emit('reset-filters')"
        >
          <slot name="filters" />
        </FilterButton>
        <slot name="actions" />
        <RefreshButton v-if="showRefresh" :refreshing="refreshing" @click="emit('refresh')" />
      </slot>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, useSlots } from "vue";
import ClearFilterButton from "./ClearFilterButton.vue";
import FilterButton from "./FilterButton.vue";
import RefreshButton from "./RefreshButton.vue";
import SearchInput from "./SearchInput.vue";
import type { SearchViewEmits, SearchViewProps } from "./types";

/**
 * The layout of a list toolbar: the search field on the left, the buttons on the right. Every
 * part is its own component and can be replaced through a slot. It holds no table and no
 * filter state; the screen binds both (see useListFilters).
 */
const props = withDefaults(defineProps<SearchViewProps>(), {
  placeholder: "",
  activeCount: 0,
  refreshing: false,
  showSearch: true,
  showClear: true,
  showFilter: undefined,
  showRefresh: true,
  filterWidth: "min(720px, 90vw)",
});
const emit = defineEmits<SearchViewEmits>();
const search = defineModel<string>("search", { default: "" });

const slots = useSlots();
const hasFilter = computed(() => props.showFilter ?? Boolean(slots.filters));
</script>
