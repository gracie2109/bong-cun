<template>
  <div class="flex min-h-[16rem] flex-col overflow-hidden rounded-xl border bg-white" :style="height ? { height } : undefined">
    <div class="table-scroll table-fill admin-table transition-opacity" :class="loading && 'opacity-60'">
      <!-- scroll-x: the table keeps at least this width and scrolls sideways when the card is narrower -->
      <div :style="scrollX ? { minWidth: typeof scrollX === 'number' ? `${scrollX}px` : scrollX } : undefined">
        <slot />
      </div>
    </div>
    <div class="flex shrink-0 flex-wrap items-center justify-between gap-x-6 gap-y-2 border-t bg-muted/40 px-4 py-2.5">
      <div class="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-muted-foreground">
        <span>{{ $t("common.table.range", { from, to, total }) }}</span>
        <label v-if="pageSize" class="flex items-center gap-2">
          {{ $t("common.row_per_page") }}
          <Select :model-value="String(pageSize)" @update:model-value="(value) => changePageSize(Number(value))">
            <SelectTrigger class="h-8 w-[70px] bg-white text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent side="top">
              <SelectItem v-for="size in sizes" :key="size" :value="String(size)">{{ size }}</SelectItem>
            </SelectContent>
          </Select>
        </label>
      </div>
      <TablePager v-model:page="page" :page-count="pageCount" :loading="loading" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useLocalStorage } from "@vueuse/core";
import { useRoute } from "vue-router";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { TABLE_PAGE_SIZES } from "@/lib/listing";
import TablePager from "./TablePager.vue";

/**
 * A table card that fills the height its parent column leaves. The rows scroll inside it, both
 * ways, with the header kept in view and the pager fixed at the foot.
 */
const props = defineProps<{
  /** Rows on this page, out of `total`. */
  count: number;
  total: number;
  pageCount: number;
  /** Dims the rows and disables the page buttons while a page is loading. */
  loading?: boolean;
  /** A fixed card height (any CSS length) instead of filling what is left. */
  height?: string;
  /** Minimum table width (px or any CSS length); a narrower card scrolls sideways. */
  scrollX?: number | string;
}>();

/** 1-based page number. */
const page = defineModel<number>("page", { required: true });
/** Rows per page; the picker is hidden when the list does not bind it. */
const pageSize = defineModel<number>("pageSize");

// The size picked on a screen is remembered for that screen.
const route = useRoute();
const savedSize = useLocalStorage<number | null>(`admin-table-size:${route.path}`, null);
if (pageSize.value !== undefined && savedSize.value && TABLE_PAGE_SIZES.includes(savedSize.value)) {
  pageSize.value = savedSize.value;
}

const sizes = computed(() =>
  [...new Set([...TABLE_PAGE_SIZES, ...(pageSize.value ? [pageSize.value] : [])])].sort((a, b) => a - b)
);

const from = computed(() => (props.total === 0 ? 0 : (page.value - 1) * (pageSize.value ?? props.count) + 1));
const to = computed(() => (props.total === 0 ? 0 : from.value + props.count - 1));

const changePageSize = (size: number) => {
  savedSize.value = size;
  pageSize.value = size;
  page.value = 1;
};
</script>
