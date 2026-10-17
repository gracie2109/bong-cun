<template>
  <div>
    <CatalogHero
      :title="catalog.activeCategoryName.value ?? $t('client.catalog.allCategories')"
      :total="catalog.total.value"
      :loading="catalog.loading.value"
      :search="catalog.filters.value.search"
      :roots="catalog.categoryTree.value"
      :category-id="catalog.filters.value.categoryId"
      @category="catalog.setCategory"
    />

    <div class="shop-container grid gap-8 pt-2 lg:grid-cols-[232px_1fr] lg:gap-10">
      <aside class="sticky top-[88px] hidden max-h-[calc(100dvh-104px)] self-start overflow-y-auto pb-6 pr-1 lg:block">
        <CatalogFilters v-bind="filterProps" @category="catalog.setCategory" @brand="catalog.setBrand" @clear="catalog.clear" />
      </aside>

      <div class="min-w-0">
        <CatalogToolbar
          v-model:search="catalog.searchText.value"
          :sort="catalog.filters.value.sort"
          :filter-count="chips.length"
          :refreshing="catalog.refreshing.value"
          @sort="catalog.setSort"
          @open-filters="filtersOpen = true"
        />
        <CatalogChips :chips="chips" class="mt-3" @clear="catalog.clear" />
        <CatalogGrid
          class="mt-5"
          :groups="catalog.groups.value"
          :total="catalog.total.value"
          :loading="catalog.loading.value"
          :refreshing="catalog.refreshing.value"
          :failed="catalog.failed.value"
          :filtered="catalog.isFiltered.value"
          :has-more="catalog.hasMore.value"
          :loading-more="catalog.loadingMore.value"
          @load-more="catalog.loadMore"
          @retry="catalog.retry"
          @clear="catalog.clear"
        />
      </div>
    </div>

    <CatalogFilterSheet v-model:open="filtersOpen" :count="chips.length" :total="catalog.total.value">
      <CatalogFilters v-bind="filterProps" @category="catalog.setCategory" @brand="catalog.setBrand" @clear="catalog.clear" />
    </CatalogFilterSheet>
  </div>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { useCatalog } from "@/features/shop/catalog/composables/useCatalog";
import { useCatalogChips } from "@/features/shop/catalog/composables/useCatalogChips";
import CatalogChips from "./components/CatalogChips.vue";
import CatalogFilterSheet from "./components/CatalogFilterSheet.vue";
import CatalogFilters from "./components/CatalogFilters.vue";
import CatalogGrid from "./components/CatalogGrid.vue";
import CatalogHero from "./components/CatalogHero.vue";
import CatalogToolbar from "./components/CatalogToolbar.vue";

const catalog = useCatalog();
const { chips, filterProps } = useCatalogChips(catalog);
const filtersOpen = ref(false);
</script>
