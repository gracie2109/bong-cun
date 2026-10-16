<template>
  <section class="border-b bg-gradient-to-b from-brand-soft/70 to-transparent">
    <div class="shop-container pb-6 pt-5 md:pb-8 md:pt-8">
      <nav :aria-label="$t('client.catalog.breadcrumb')" class="text-sm text-muted-foreground">
        <RouterLink :to="{ name: 'home' }" class="hover:text-foreground">{{ $t("client.nav.home") }}</RouterLink>
        <span class="mx-2 opacity-50">/</span>
        <span class="text-foreground">{{ $t("client.nav.products") }}</span>
      </nav>
      <div class="mt-4 flex flex-wrap items-end justify-between gap-x-6 gap-y-2">
        <h1 class="shop-display text-3xl md:text-[40px] md:leading-[1.1]">{{ title }}</h1>
        <p class="text-sm text-muted-foreground md:text-base" aria-live="polite">
          <span v-if="loading" class="shop-skeleton inline-block h-4 w-28 rounded-full align-middle" />
          <template v-else-if="search">{{ $t("client.catalog.resultsFor", { count: total, q: search }) }}</template>
          <template v-else>{{ $t("client.catalog.found", { count: total }) }}</template>
        </p>
      </div>
      <CategoryPills v-if="roots.length > 0" class="mt-5" :roots="roots" :selected="categoryId" @select="emit('category', $event)" />
    </div>
  </section>
</template>

<script lang="ts" setup>
import type { CategoryNode } from "@bongcun/core/shop";
import CategoryPills from "./CategoryPills.vue";

defineProps<{
  title: string;
  total: number;
  loading: boolean;
  search: string;
  roots: CategoryNode[];
  categoryId: string | null;
}>();
const emit = defineEmits<{ category: [id: string | null] }>();
</script>
