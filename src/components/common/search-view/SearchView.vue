<template>
  <div class="flex flex-wrap items-center gap-2 rounded-xl border bg-white p-3">
    <div v-if="showSearch" class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="placeholder" @keydown.enter.prevent="emit('apply')" />
    </div>
    <div v-else class="flex-1" />
    <slot name="quick" />
    <div class="flex items-center gap-2">
      <ToolbarIconButton v-if="showClear" :label="$t('common.searchView.clear')" :disabled="!search && !activeCount" @click="emit('clear')">
        <FilterX class="size-4" />
      </ToolbarIconButton>
      <SearchViewFilterPopover
        v-if="hasFilter"
        v-model:open="filterOpen"
        :active-count="activeCount"
        :width="filterWidth"
        @apply="emit('apply')"
        @reset="emit('reset-filters')"
      >
        <slot name="filters" />
      </SearchViewFilterPopover>
      <slot name="actions" />
      <ToolbarIconButton v-if="showRefresh" :label="$t('common.searchView.refresh')" :disabled="refreshing" @click="emit('refresh')">
        <RefreshCw class="size-4" :class="refreshing && 'animate-spin'" />
      </ToolbarIconButton>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, useSlots, watch } from "vue";
import { FilterX, RefreshCw, Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import SearchViewFilterPopover from "./SearchViewFilterPopover.vue";
import ToolbarIconButton from "./ToolbarIconButton.vue";
import type { SearchViewEmits, SearchViewProps } from "./types";

/**
 * The toolbar above a list: a search box, then Clear, Filter (popover), the screen's own buttons
 * and Refresh. It holds no table and no filter state; the screen binds both (see useListFilters).
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

const filterOpen = ref(false);
watch(filterOpen, (isOpen) => {
  if (isOpen) emit("open-filters");
});
</script>
