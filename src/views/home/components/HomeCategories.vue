<template>
  <section v-if="loading || categories.length > 0" class="shop-container pt-14 md:pt-20">
    <SectionHeading :eyebrow="$t('client.home.categories.eyebrow')" :title="$t('client.home.categories.title')" />
    <ul class="shop-scroll-row -mx-4 mt-8 px-4 sm:mx-0 sm:grid sm:gap-5 sm:overflow-visible sm:px-0" :class="gridCols">
      <template v-if="loading">
        <li v-for="n in 4" :key="n" class="w-[44%] shrink-0 sm:w-auto"><div class="shop-skeleton aspect-[4/3] rounded-2xl" /></li>
      </template>
      <template v-else>
        <li v-for="(category, index) in categories" :key="category.id" class="shop-reveal w-[44%] shrink-0 snap-start sm:w-auto" :style="{ '--i': index }">
          <CategoryTile :category="category" />
        </li>
        <li class="w-[44%] shrink-0 snap-start sm:w-auto" :class="allSpan">
          <RouterLink
            :to="{ name: 'products' }"
            class="group flex h-full min-h-[150px] flex-col justify-between gap-6 rounded-2xl bg-foreground p-5 text-white transition-colors duration-300 hover:bg-primary sm:p-6"
          >
            <ShoppingBasket class="size-7" :stroke-width="1.6" />
            <span class="flex items-end justify-between gap-3">
              <span>
                <span class="block text-lg font-bold leading-snug">{{ $t("client.home.categories.all") }}</span>
                <span v-if="wideAll" class="mt-1 hidden text-sm text-white/70 sm:block">{{ $t("client.home.categories.allText") }}</span>
              </span>
              <ArrowRight class="size-5 shrink-0 transition-transform duration-200 group-hover:translate-x-1" />
            </span>
          </RouterLink>
        </li>
      </template>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ArrowRight, ShoppingBasket } from "lucide-vue-next";
import SectionHeading from "@/components/shop/SectionHeading.vue";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";
import { useProductCategories } from "@/queries/productCategories";
import CategoryTile from "./CategoryTile.vue";

const query = useProductCategories({ pageIndex: 1, pageSize: 12 }, { rootsOnly: true });
useServerPrefetch(query);
const loading = computed(() => query.isLoading.value);
const categories = computed(() => (query.data.value?.rows ?? []).filter((row) => row.isActive));

// The grid follows the real number of categories: 3 columns on tablets, 4 (few categories) or 6 on
// desktop. The last tile, "all products", stretches over the rest of the row, so a shop with one or
// two categories shows a full row instead of two small tiles and blank space.
const SM_SPAN = ["", "sm:col-span-2", "sm:col-span-3"] as const;
const LG_SPAN = ["", "lg:col-span-2", "lg:col-span-3", "lg:col-span-4", "lg:col-span-5", "lg:col-span-6"] as const;
const lgCols = computed(() => (categories.value.length <= 3 ? 4 : 6));
const gridCols = computed(() => (lgCols.value === 4 ? "sm:grid-cols-3 lg:grid-cols-4" : "sm:grid-cols-3 lg:grid-cols-6"));
const restOf = (cols: number) => cols - (categories.value.length % cols);
const allSpan = computed(() => [SM_SPAN[restOf(3) - 1], LG_SPAN[restOf(lgCols.value) - 1]]);
const wideAll = computed(() => restOf(lgCols.value) > 1);
</script>
