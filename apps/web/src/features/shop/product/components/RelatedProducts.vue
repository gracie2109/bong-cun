<template>
  <section v-if="groups.length > 0" class="mt-14 border-t pt-10 md:mt-20">
    <SectionHeading :title="$t('client.product.related')" :link-to="{ name: 'products' }" :link-label="$t('client.home.viewAll')" />
    <ul class="mt-8 grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 sm:gap-x-5 lg:grid-cols-4">
      <li v-for="group in groups.slice(0, 8)" :key="group.id"><ProductCard :group="group" /></li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import ProductCard from "@/components/shop/ProductCard.vue";
import SectionHeading from "@/components/shop/SectionHeading.vue";
import type { ShopGroup } from "@bongcun/core/shop";

defineProps<{ groups: ShopGroup[] }>();
</script>
