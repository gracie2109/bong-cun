<template>
  <div class="sticky top-16 z-20 -mx-4 bg-background/90 px-4 py-3 backdrop-blur-md sm:mx-0 sm:px-0 lg:top-[72px]">
    <div class="flex items-center gap-2 sm:gap-3">
      <div class="relative min-w-0 flex-1">
        <label for="catalog-search" class="sr-only">{{ $t("client.catalog.searchLabel") }}</label>
        <Search class="pointer-events-none absolute left-4 top-1/2 size-[18px] -translate-y-1/2 text-muted-foreground" />
        <input
          id="catalog-search"
          v-model="search"
          type="search"
          enterkeyhint="search"
          autocomplete="off"
          class="h-11 w-full rounded-full border bg-white pl-11 pr-10 text-sm outline-none transition-[border-color,box-shadow] duration-200 placeholder:text-muted-foreground focus:border-primary/50 focus:shadow-[0_0_0_4px_hsl(var(--primary)/0.12)]"
          :placeholder="$t('client.catalog.searchPlaceholder')"
        />
        <button
          v-if="search"
          type="button"
          class="absolute right-1.5 top-1/2 grid size-8 -translate-y-1/2 place-content-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground"
          :aria-label="$t('client.catalog.clearSearch')"
          @click="search = ''"
        >
          <X class="size-4" />
        </button>
      </div>
      <button
        type="button"
        class="relative inline-flex h-11 shrink-0 items-center gap-2 rounded-full border bg-white px-4 text-sm font-medium transition-colors hover:border-foreground/40 lg:hidden"
        @click="emit('openFilters')"
      >
        <SlidersHorizontal class="size-4" /><span class="hidden sm:inline">{{ $t("client.catalog.filters") }}</span>
        <span v-if="filterCount > 0" class="grid size-5 place-content-center rounded-full bg-primary text-[11px] font-bold text-white">
          {{ filterCount }}
        </span>
      </button>
      <CatalogSort :model-value="sort" @update:model-value="emit('sort', $event)" />
    </div>
    <div class="absolute inset-x-0 bottom-0 h-0.5 overflow-hidden" aria-hidden="true">
      <div v-if="refreshing" class="toolbar-progress h-full w-1/3 rounded-full bg-primary" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Search, SlidersHorizontal, X } from "lucide-vue-next";
import type { CatalogSort as Sort } from "@/types/catalog";
import CatalogSort from "./CatalogSort.vue";

defineProps<{ sort: Sort; filterCount: number; refreshing: boolean }>();
const search = defineModel<string>("search", { required: true });
const emit = defineEmits<{ sort: [value: Sort]; openFilters: [] }>();
</script>

<style scoped>
.toolbar-progress {
  animation: toolbar-progress 1s var(--ease-in-out) infinite;
}
@keyframes toolbar-progress {
  from {
    transform: translateX(-100%);
  }
  to {
    transform: translateX(300%);
  }
}
</style>
