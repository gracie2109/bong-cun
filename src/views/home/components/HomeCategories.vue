<template>
  <section v-if="loading || categories.length > 0" class="shop-container pt-16 md:pt-24">
    <SectionHeading
      :eyebrow="$t('client.home.categories.eyebrow')"
      :title="$t('client.home.categories.title')"
      :link-to="{ name: 'products' }"
      :link-label="$t('client.home.viewAll')"
    />
    <ul class="shop-scroll-row -mx-4 mt-8 px-4 sm:mx-0 sm:grid sm:grid-cols-3 sm:gap-4 sm:overflow-visible sm:px-0 lg:grid-cols-6">
      <template v-if="loading">
        <li v-for="n in 6" :key="n" class="w-[38%] shrink-0 sm:w-auto"><div class="shop-skeleton aspect-square rounded-3xl" /></li>
      </template>
      <li
        v-for="(category, index) in categories"
        v-else
        :key="category.id"
        class="shop-reveal w-[38%] shrink-0 snap-start sm:w-auto"
        :style="{ '--i': index }"
      >
        <RouterLink :to="{ name: 'products', query: { category: category.id } }" class="group block text-center">
          <span class="relative block aspect-square overflow-hidden rounded-3xl bg-white ring-1 ring-border/70 transition-shadow duration-300 group-hover:shadow-lift">
            <img
              v-if="category.imageUrl"
              :src="category.imageUrl"
              :alt="''"
              loading="lazy"
              class="size-full object-contain p-[14%] transition-transform duration-500 ease-out-quart group-hover:scale-[1.06]"
            />
            <span v-else class="grid size-full place-content-center bg-brand-soft text-brand"><PawMark class="size-12" /></span>
          </span>
          <span class="mt-3 block text-sm font-semibold group-hover:text-primary sm:text-[15px]">{{ category.name }}</span>
          <span v-if="category.productCount > 0" class="block text-xs text-muted-foreground">
            {{ $t("client.home.categories.count", { n: category.productCount }) }}
          </span>
        </RouterLink>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import PawMark from "@/components/shop/PawMark.vue";
import SectionHeading from "@/components/shop/SectionHeading.vue";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";
import { useProductCategories } from "@/queries/productCategories";

const query = useProductCategories({ pageIndex: 1, pageSize: 12 }, { rootsOnly: true });
useServerPrefetch(query);
const loading = computed(() => query.isLoading.value);
const categories = computed(() => (query.data.value?.rows ?? []).filter((row) => row.isActive));
</script>
