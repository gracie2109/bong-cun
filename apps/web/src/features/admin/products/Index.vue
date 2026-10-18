<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Package class="size-4 text-primary" />
      {{ $t("products.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <ProductsNav />
        <Button v-if="canCreate" @click="openForm(null)">
          <Plus class="mr-2 size-4" />
          {{ $t("products.add") }}
        </Button>
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('products.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #filters>
          <ProductsFilterFields
            v-model:category-id="draft.categoryId"
            v-model:brand-id="draft.brandId"
            v-model:show-archived="draft.showArchived"
          />
        </template>
      </SearchView>

      <ProductsBulkBar v-if="selection.count.value > 0" :count="selection.count.value" @clear="selection.clear" @delete="removal.ask(selection.ids.value)" />

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th v-if="canDelete" class="w-10 px-4 py-3">
                <Checkbox
                  :checked="selection.allOnPage.value ? true : selection.someOnPage.value ? 'indeterminate' : false"
                  :aria-label="$t('products.delete.selectPage')"
                  @update:checked="(value) => selection.togglePage(value === true)"
                />
              </th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.product") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.category") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.brand") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.variants") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.form.sku") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("products.form.price") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="canDelete ? 8 : 7" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('products.empty')" />
            <ProductRow
              v-for="row in rows"
              :key="row.id"
              :group="row"
              :can-update="canUpdate"
              :can-delete="canDelete"
              :selected="selection.isSelected(row.id)"
              @edit="openForm"
              @set-active="setActive"
              @select="selection.toggle"
              @delete="(id) => removal.ask([id])"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <ProductGroupSheet v-model:open="formOpen" :group-id="editingId" />

    <ConfirmDialog
      :open="removal.pendingIds.value.length > 0"
      :title="$t('products.delete.confirmTitle', { n: removal.pendingIds.value.length })"
      :desc="$t('products.delete.confirmDesc')"
      :ok-btn="$t('products.delete.action')"
      danger
      @open-change="removal.cancel"
      @cancel="removal.cancel"
      @handle-ok="removal.confirm"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Package, Plus } from "lucide-vue-next";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { usePagedList } from "@/composables/usePagedList";
import { usePermission } from "@/composables/usePermission";
import { useProductGroups, useSetProductGroupActive } from "@/features/shared/products";
import type { ProductGroup } from "@bongcun/supabase/products";
import { ContentWrap, Header } from "@/features/admin/components";
import ProductGroupSheet from "./ProductGroupSheet.vue";
import ProductRow from "./ProductRow.vue";
import ProductsBulkBar from "./ProductsBulkBar.vue";
import ProductsFilterFields from "./ProductsFilterFields.vue";
import ProductsNav from "./ProductsNav.vue";
import { useProductDelete } from "./useProductDelete";
import { useProductSelection } from "./useProductSelection";
import { useProductsFilters } from "./useProductsFilters";

const { canCreate, canUpdate, canDelete } = usePermission("products");
const { search, page, filter, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useProductsFilters();
const formOpen = ref(false);
const editingId = ref<string | null>(null);

const listQuery = useProductGroups(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const selection = useProductSelection(computed(() => rows.value.map((row) => row.id)));
const removal = useProductDelete(selection.remove);
const setActiveMutation = useSetProductGroupActive();

const openForm = (id: string | null) => {
  editingId.value = id;
  formOpen.value = true;
};

const setActive = async (group: ProductGroup, isActive: boolean) => {
  try {
    await setActiveMutation.mutateAsync({ id: group.id, isActive });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
