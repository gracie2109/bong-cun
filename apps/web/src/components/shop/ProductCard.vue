<template>
  <article class="group relative flex h-full flex-col">
    <div class="relative overflow-hidden rounded-2xl bg-white ring-1 ring-border/70 transition-shadow duration-300 group-hover:shadow-lift">
      <RouterLink :to="detailLink" class="block aspect-square" tabindex="-1" aria-hidden="true">
        <img
          v-if="cover"
          :src="cover"
          :alt="group.name"
          loading="lazy"
          decoding="async"
          class="size-full object-contain p-[8%] transition-transform duration-500 ease-out-quart group-hover:scale-[1.04]"
          :class="{ 'opacity-50 grayscale': !group.inStock }"
        />
        <span v-else class="flex size-full flex-col items-center justify-center gap-2 bg-secondary text-muted-foreground">
          <PawMark class="size-10 text-brand/40" />
          <span class="text-xs font-medium">{{ $t("client.catalog.noPhoto") }}</span>
        </span>
      </RouterLink>

      <div class="pointer-events-none absolute left-2.5 top-2.5 flex flex-col items-start gap-1.5">
        <StockBadge v-if="!group.inStock" kind="out">{{ $t("client.catalog.outOfStock") }}</StockBadge>
      </div>

      <button
        type="button"
        class="quick-add absolute bottom-2.5 right-2.5 inline-flex h-10 items-center gap-1.5 rounded-full bg-foreground pl-3 pr-3.5 text-sm font-semibold text-white shadow-lg transition-[transform,opacity,background-color] duration-300 ease-out-quart hover:bg-primary active:scale-95 disabled:bg-muted-foreground"
        :disabled="!group.inStock"
        :aria-label="$t('client.catalog.quickAdd', { name: group.name })"
        @click="openQuickView"
      >
        <Plus class="size-4" :stroke-width="2.5" /><span class="hidden sm:inline">{{ $t("client.catalog.add") }}</span>
      </button>
    </div>

    <div class="flex flex-1 flex-col gap-1 px-0.5 pt-3">
      <p v-if="group.brandName" class="truncate text-[11px] font-semibold uppercase tracking-[0.08em] text-muted-foreground">
        {{ group.brandName }}
      </p>
      <h3 class="line-clamp-2 text-[15px] font-medium leading-snug">
        <RouterLink :to="detailLink" class="outline-none after:absolute after:inset-0 after:rounded-2xl hover:text-primary focus-visible:underline">
          {{ group.name }}
        </RouterLink>
      </h3>
      <p v-if="optionHint" class="truncate text-xs text-muted-foreground">{{ optionHint }}</p>
      <PriceDisplay class="mt-auto pt-1.5" :amount="group.minPrice" :from="hasRange" />
    </div>
    <ShopQuickView v-if="quickMounted" v-model:open="quickOpen" :group="group" />
  </article>
</template>

<script lang="ts" setup>
import { computed, defineAsyncComponent, ref } from "vue";
import { Plus } from "lucide-vue-next";
import type { ShopGroup } from "@/types/catalog";
import { groupCover, groupOptionHint, groupHasPriceRange } from "@/utils/shop/catalog";
import PawMark from "./PawMark.vue";
import PriceDisplay from "./PriceDisplay.vue";
import StockBadge from "./StockBadge.vue";

// Loaded on the first "add" click, so a grid of 24 cards does not build 24 dialogs up front.
const ShopQuickView = defineAsyncComponent(() => import("./ShopQuickView.vue"));

const props = defineProps<{ group: ShopGroup }>();

const detailLink = computed(() => ({ name: "product-detail", params: { id: props.group.id } }));
const cover = computed(() => groupCover(props.group));
const optionHint = computed(() => groupOptionHint(props.group));
const hasRange = computed(() => groupHasPriceRange(props.group));

const quickMounted = ref(false);
const quickOpen = ref(false);
const openQuickView = () => {
  quickMounted.value = true;
  quickOpen.value = true;
};
</script>

<style scoped>
/* The whole card is a link (the title's ::after); the add button sits above it. */
.quick-add {
  z-index: 1;
}
@media (hover: hover) and (pointer: fine) {
  .quick-add:not(:focus-visible) {
    opacity: 0;
    transform: translateY(8px);
  }
  .group:hover .quick-add,
  .group:focus-within .quick-add {
    opacity: 1;
    transform: none;
  }
}
</style>
