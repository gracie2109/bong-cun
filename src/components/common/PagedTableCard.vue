<template>
  <div class="overflow-hidden rounded-xl border bg-white">
    <div class="flex items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
      <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
        {{ $t("petCare.common.showing", { count, total }) }}
      </span>
      <TablePager v-model:page="page" :page-count="pageCount" :loading="loading" />
    </div>
    <div class="table-scroll">
      <slot />
    </div>
  </div>
</template>

<script lang="ts" setup>
import TablePager from "./TablePager.vue";

/** A table inside a card whose header shows "showing n of total" and the page buttons. */
defineProps<{
  /** Rows on this page, out of `total`. */
  count: number;
  total: number;
  pageCount: number;
  /** Disables the page buttons while a page is loading. */
  loading?: boolean;
}>();

/** 1-based page number. */
const page = defineModel<number>("page", { required: true });
</script>
