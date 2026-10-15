<template>
  <div v-if="loading" class="grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 xl:grid-cols-4" :aria-label="$t('petCare.common.loading')">
    <ProductCardSkeleton v-for="n in 8" :key="n" />
  </div>

  <EmptyState v-else-if="failed" tone="error" :title="$t('client.catalog.error')" :text="$t('client.catalog.errorHint')">
    <template #icon><WifiOff class="size-10" /></template>
    <Button class="h-11 rounded-full px-6" @click="emit('retry')">{{ $t("client.catalog.retry") }}</Button>
  </EmptyState>

  <EmptyState v-else-if="groups.length === 0" :title="$t('client.catalog.empty')" :text="$t(filtered ? 'client.catalog.emptyHint' : 'client.catalog.emptyShop')">
    <Button v-if="filtered" class="h-11 rounded-full px-6" @click="emit('clear')">{{ $t("client.catalog.clear") }}</Button>
    <Button variant="outline" as-child class="h-11 rounded-full px-6">
      <RouterLink :to="{ name: 'spa' }">{{ $t("client.catalog.seeSpa") }}</RouterLink>
    </Button>
  </EmptyState>

  <template v-else>
    <ul
      class="grid grid-cols-2 gap-x-4 gap-y-8 transition-opacity duration-300 sm:grid-cols-3 sm:gap-x-5 xl:grid-cols-4"
      :class="{ 'opacity-60': refreshing }"
      :aria-busy="refreshing"
    >
      <li v-for="(group, index) in groups" :key="group.id" class="shop-reveal" :style="{ '--i': revealIndex(index) }">
        <ProductCard :group="group" />
      </li>
    </ul>
    <CatalogLoadMore
      :shown="groups.length"
      :total="total"
      :has-more="hasMore"
      :loading-more="loadingMore"
      @load-more="emit('loadMore')"
    />
  </template>
</template>

<script lang="ts" setup>
import { WifiOff } from "lucide-vue-next";
import EmptyState from "@/components/shop/EmptyState.vue";
import ProductCard from "@/components/shop/ProductCard.vue";
import ProductCardSkeleton from "@/components/shop/ProductCardSkeleton.vue";
import { Button } from "@/components/ui/button";
import type { ShopGroup } from "@/types/catalog";
import { revealIndex } from "@/utils/shop/motion";
import CatalogLoadMore from "./CatalogLoadMore.vue";

defineProps<{
  groups: ShopGroup[];
  total: number;
  loading: boolean;
  refreshing: boolean;
  failed: boolean;
  filtered: boolean;
  hasMore: boolean;
  loadingMore: boolean;
}>();
const emit = defineEmits<{ loadMore: []; retry: []; clear: [] }>();
</script>
