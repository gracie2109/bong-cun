<template>
  <div class="mt-12 flex flex-col items-center gap-4 text-center">
    <div v-if="loadingMore" class="grid w-full grid-cols-2 gap-x-4 sm:grid-cols-3 xl:grid-cols-4" aria-hidden="true">
      <ProductCardSkeleton v-for="n in 4" :key="n" :class="SKELETON_SHOW[n - 1]" />
    </div>
    <p class="text-sm text-muted-foreground">{{ $t("client.catalog.showing", { shown, total }) }}</p>
    <div class="h-1 w-48 overflow-hidden rounded-full bg-muted" aria-hidden="true">
      <div class="h-full rounded-full bg-primary transition-[width] duration-500 ease-out-quart" :style="{ width: `${progress}%` }" />
    </div>
    <template v-if="hasMore">
      <ScrollSentinel @visible="!loadingMore && emit('loadMore')" />
      <Button variant="outline" class="h-11 rounded-full px-6" :disabled="loadingMore" @click="emit('loadMore')">
        {{ $t("client.catalog.loadMore") }}
      </Button>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import ScrollSentinel from "@/components/common/ScrollSentinel.vue";
import ProductCardSkeleton from "@/components/shop/ProductCardSkeleton.vue";
import { Button } from "@/components/ui/button";

// One row of placeholders: 2, 3 or 4 cards wide like the grid.
const SKELETON_SHOW = ["", "", "hidden sm:block", "hidden xl:block"];

const props = defineProps<{ shown: number; total: number; hasMore: boolean; loadingMore: boolean }>();
const emit = defineEmits<{ loadMore: [] }>();

const progress = computed(() => (props.total > 0 ? Math.min(100, (props.shown / props.total) * 100) : 0));
</script>
