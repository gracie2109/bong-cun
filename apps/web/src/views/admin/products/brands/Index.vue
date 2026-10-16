<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <BadgeCheck class="size-4 text-primary" />
      {{ $t("productCatalog.brands.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <ProductsNav />
        <Button v-if="canCreate" @click="openForm(null)">
          <Plus class="mr-2 size-4" />
          {{ $t("productCatalog.brands.add") }}
        </Button>
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('productCatalog.brands.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #filters>
          <label class="flex items-center gap-2 text-sm text-muted-foreground">
            <Switch v-model:checked="draft.showInactive" />
            {{ $t("productCatalog.showInactive") }}
          </label>
        </template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("productCatalog.name") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("productCatalog.slug") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("productCatalog.productCount") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="4" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('productCatalog.brands.empty')" />
            <BrandRow
              v-for="row in rows"
              :key="row.id"
              :brand="row"
              :can-update="canUpdate"
              :can-delete="canDelete"
              @edit="openForm"
              @set-active="setActive"
              @remove="deleting = $event"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <BrandDialog v-model:open="formOpen" :brand="editing" />
    <ConfirmDialog
      :open="Boolean(deleting)"
      danger
      :title="$t('productCatalog.brands.deleteTitle', { name: deleting?.name ?? '' })"
      :desc="$t('productCatalog.deleteDesc')"
      :ok-btn="$t('common.delete')"
      @cancel="deleting = null"
      @open-change="deleting = null"
      @handle-ok="confirmDelete"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { BadgeCheck, Plus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { usePagedList } from "@/composables/usePagedList";
import { useListFilters } from "@/composables/useListFilters";
import { usePermission } from "@/composables/usePermission";
import { useDeleteProductBrand, useProductBrands, useSaveProductBrand } from "@/queries/productCategories";
import type { CatalogFilter, ProductBrand } from "@bongcun/supabase/products";
import { ContentWrap, Header } from "@/views/admin/components";
import ProductsNav from "../ProductsNav.vue";
import BrandDialog from "./BrandDialog.vue";
import BrandRow from "./BrandRow.vue";

const PAGE_SIZE = 20;

const { canCreate, canUpdate, canDelete } = usePermission("products");
const { search, debouncedSearch, page, applied, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } =
  useListFilters({ pageSize: PAGE_SIZE, defaults: { showInactive: false } });
const formOpen = ref(false);
const editing = ref<ProductBrand | null>(null);
const deleting = ref<ProductBrand | null>(null);

const filter = computed<CatalogFilter>(() => ({ search: debouncedSearch.value, includeInactive: applied.value.showInactive }));
const listQuery = useProductBrands(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const saveMutation = useSaveProductBrand();
const deleteMutation = useDeleteProductBrand();

const openForm = (brand: ProductBrand | null) => {
  editing.value = brand;
  formOpen.value = true;
};

const setActive = async (brand: ProductBrand, isActive: boolean) => {
  try {
    await saveMutation.mutateAsync({ id: brand.id, name: brand.name, imageUrl: brand.imageUrl ?? "", isActive });
  } catch {
    // the mutation already showed the failure toast
  }
};

const confirmDelete = async () => {
  const target = deleting.value;
  if (!target) return;
  try {
    await deleteMutation.mutateAsync(target.id);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
