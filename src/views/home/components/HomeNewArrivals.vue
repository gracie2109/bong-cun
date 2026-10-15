<template>
  <section v-if="!isError && (isPending || groups.length > 0)" class="shop-container pt-16 md:pt-24">
    <SectionHeading
      :eyebrow="$t('client.home.newArrivals.eyebrow')"
      :title="$t('client.home.newArrivals.title')"
      :link-to="{ name: 'products' }"
      :link-label="$t('client.home.viewAll')"
    />
    <ul class="mt-8 grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 sm:gap-x-5 lg:grid-cols-4">
      <template v-if="isPending">
        <li v-for="n in 4" :key="n"><ProductCardSkeleton /></li>
      </template>
      <li v-for="(group, index) in groups" v-else :key="group.id" class="shop-reveal" :style="{ '--i': index }">
        <ProductCard :group="group" />
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import ProductCard from "@/components/shop/ProductCard.vue";
import ProductCardSkeleton from "@/components/shop/ProductCardSkeleton.vue";
import SectionHeading from "@/components/shop/SectionHeading.vue";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";
import { useShopCatalog } from "@/queries/shopCatalog";

const NEW_ARRIVALS = 8;
const { groups, query } = useShopCatalog({ sort: "newest" }, NEW_ARRIVALS);
const { isPending, isError } = query;
useServerPrefetch(query);
</script>
