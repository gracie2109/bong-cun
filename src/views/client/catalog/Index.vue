<template>
  <div class="container space-y-4 py-6">
    <Breadcrumb>
      <BreadcrumbList>
        <BreadcrumbItem>
          <BreadcrumbLink as-child><RouterLink :to="{ name: 'home' }">{{ $t("client.nav.home") }}</RouterLink></BreadcrumbLink>
        </BreadcrumbItem>
        <BreadcrumbSeparator />
        <BreadcrumbItem><BreadcrumbPage>{{ $t("client.nav.products") }}</BreadcrumbPage></BreadcrumbItem>
      </BreadcrumbList>
    </Breadcrumb>

    <div class="grid gap-6 lg:grid-cols-[260px_1fr]">
      <aside class="hidden self-start rounded-xl border bg-white p-4 lg:block">
        <CatalogFilters v-bind="filterProps" @category="catalog.setCategory" @brand="catalog.setBrand" @clear="catalog.clear" />
      </aside>

      <div class="min-w-0 space-y-4">
        <CatalogToolbar
          v-model:search="catalog.searchText.value"
          :sort="catalog.filters.value.sort"
          :total="catalog.total.value"
          :chips="chips"
          @sort="catalog.setSort"
          @open-filters="filtersOpen = true"
        />
        <CatalogGrid
          :groups="catalog.groups.value"
          :total="catalog.total.value"
          :loading="catalog.loading.value"
          :failed="catalog.failed.value"
          :has-more="catalog.hasMore.value"
          :loading-more="catalog.loadingMore.value"
          @load-more="catalog.loadMore"
          @retry="catalog.retry"
        />
      </div>
    </div>

    <Sheet v-model:open="filtersOpen">
      <SheetContent side="left" class="w-[300px] overflow-y-auto">
        <SheetHeader><SheetTitle>{{ $t("client.catalog.filters") }}</SheetTitle></SheetHeader>
        <div class="mt-4">
          <CatalogFilters v-bind="filterProps" @category="pickCategory" @brand="pickBrand" @clear="catalog.clear" />
        </div>
      </SheetContent>
    </Sheet>
  </div>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { Breadcrumb, BreadcrumbItem, BreadcrumbLink, BreadcrumbList, BreadcrumbPage, BreadcrumbSeparator } from "@/components/ui/breadcrumb";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { useCatalog } from "@/composables/shop/useCatalog";
import { useCatalogChips } from "@/composables/shop/useCatalogChips";
import CatalogFilters from "./components/CatalogFilters.vue";
import CatalogGrid from "./components/CatalogGrid.vue";
import CatalogToolbar from "./components/CatalogToolbar.vue";

const catalog = useCatalog();
const { chips, filterProps } = useCatalogChips(catalog);

const filtersOpen = ref(false);
const pickCategory = (id: string | null) => {
  catalog.setCategory(id);
  filtersOpen.value = false;
};
const pickBrand = (id: string | null) => {
  catalog.setBrand(id);
  filtersOpen.value = false;
};
</script>
