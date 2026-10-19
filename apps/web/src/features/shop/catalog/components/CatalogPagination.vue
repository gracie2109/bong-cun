<template>
  <nav v-if="pageCount > 1" class="mt-12 flex flex-col items-center gap-4 text-center" :aria-label="$t('client.catalog.showing', { shown, total })">
    <p class="text-sm text-muted-foreground">{{ $t("client.catalog.showing", { shown, total }) }}</p>
    <ul class="flex flex-wrap items-center justify-center gap-1.5">
      <li>
        <PageLink :to="target(page - 1)" :disabled="page <= 1" :label="$t('client.catalog.prevPage')">
          <ChevronLeft class="size-4" />
        </PageLink>
      </li>
      <li v-for="(item, index) in items" :key="`${item}-${index}`">
        <span v-if="item === 'gap'" class="px-1 text-muted-foreground" aria-hidden="true">…</span>
        <PageLink v-else :to="target(item)" :current="item === page" :label="$t('client.catalog.pageLabel', { n: item })">
          {{ item }}
        </PageLink>
      </li>
      <li>
        <PageLink :to="target(page + 1)" :disabled="page >= pageCount" :label="$t('client.catalog.nextPage')">
          <ChevronRight class="size-4" />
        </PageLink>
      </li>
    </ul>
  </nav>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { pageItems } from "@/utils/shop/pagination";
import PageLink from "./PageLink.vue";

const props = defineProps<{
  page: number;
  pageSize: number;
  total: number;
  shown: number;
  /** The URL query of the current filters; the page link adds `page` to it. */
  query: Record<string, string>;
}>();

const pageCount = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)));
const items = computed(() => pageItems(props.page, pageCount.value));
const target = (page: number) => ({ query: page > 1 ? { ...props.query, page: String(page) } : props.query });
</script>
