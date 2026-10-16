<template>
  <section v-if="!isError && (isPending || groups.length > 0)" class="shop-container pt-14 md:pt-20">
    <SectionHeading
      :eyebrow="$t('client.home.newArrivals.eyebrow')"
      :title="$t('client.home.newArrivals.title')"
      :link-to="{ name: 'products' }"
      :link-label="$t('client.home.viewAll')"
    />
    <ul class="mt-8 grid grid-cols-2 gap-x-4 gap-y-10 sm:grid-cols-3 sm:gap-x-5 lg:grid-cols-4 lg:gap-x-6">
      <template v-if="isPending">
        <li v-for="n in SHOWN" :key="n" :class="{ 'sm:max-lg:hidden': n > 6 }"><ProductCardSkeleton /></li>
      </template>
      <li
        v-for="(group, index) in shown"
        v-else
        :key="group.id"
        class="shop-reveal"
        :class="{ 'sm:max-lg:hidden': index >= 6 }"
        :style="{ '--i': index }"
      >
        <ProductCard :group="group" />
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import ProductCard from "@/components/shop/ProductCard.vue";
import ProductCardSkeleton from "@/components/shop/ProductCardSkeleton.vue";
import SectionHeading from "@/components/shop/SectionHeading.vue";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";
import { useShopCatalog } from "@/queries/shopCatalog";
import { showcaseOrder } from "@/utils/shop/catalog";

/** Full rows at every width: 8 cards in 2 or 4 columns, 6 in 3 columns; picked from the newest products. */
const SHOWN = 8;
const POOL = 16;
const { groups, query } = useShopCatalog({ sort: "newest" }, POOL);
const { isPending, isError } = query;
useServerPrefetch(query);
const shown = computed(() => showcaseOrder(groups.value).slice(0, SHOWN));
</script>
