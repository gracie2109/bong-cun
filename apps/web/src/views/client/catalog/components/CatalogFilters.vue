<template>
  <div class="space-y-7">
    <div class="flex items-center justify-between">
      <h2 class="text-base font-bold">{{ $t("client.catalog.filters") }}</h2>
      <button v-if="isFiltered" type="button" class="text-sm font-semibold text-primary hover:underline" @click="emit('clear')">
        {{ $t("client.catalog.clear") }}
      </button>
    </div>

    <section class="space-y-2">
      <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{{ $t("client.catalog.categories") }}</h3>
      <CategoryTree :tree="categoryTree" :selected="categoryId" @select="emit('category', $event)" />
    </section>

    <section v-if="brands.length > 0" class="space-y-2">
      <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{{ $t("client.catalog.brands") }}</h3>
      <BrandFilter :brands="brands" :selected="brandId" @select="emit('brand', $event)" />
    </section>
  </div>
</template>

<script lang="ts" setup>
import type { CategoryNode } from "@/types/catalog";
import BrandFilter from "./BrandFilter.vue";
import CategoryTree from "./CategoryTree.vue";

defineProps<{
  categoryTree: CategoryNode[];
  brands: { id: string; name: string }[];
  categoryId: string | null;
  brandId: string | null;
  isFiltered: boolean;
}>();
const emit = defineEmits<{ category: [id: string | null]; brand: [id: string | null]; clear: [] }>();
</script>
