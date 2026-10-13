<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <FolderTree class="size-4 text-primary" />
      {{ $t("productCatalog.categories.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <ProductsNav />
        <Button v-if="canCreate" @click="openForm(null)">
          <Plus class="mr-2 size-4" />
          {{ $t("productCatalog.categories.add") }}
        </Button>
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('productCatalog.categories.searchPlaceholder')" />
        </div>
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model:checked="showInactive" />
          {{ $t("productCatalog.showInactive") }}
        </label>
      </div>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("productCatalog.name") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("productCatalog.slug") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("productCatalog.productCount") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("productCatalog.order") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('productCatalog.categories.empty')" />
            <CategoryRow
              v-for="row in rows"
              :key="row.id"
              :category="row"
              :can-update="canUpdate"
              :can-delete="canDelete"
              :can-move="!debouncedSearch"
              :show-parent="Boolean(debouncedSearch)"
              @edit="openForm"
              @set-active="setActive"
              @move="move"
              @remove="deleting = $event"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <CategoryDialog v-model:open="formOpen" :category="editing" />
    <ConfirmDialog
      :open="Boolean(deleting)"
      danger
      :title="$t('productCatalog.categories.deleteTitle', { name: deleting?.name ?? '' })"
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
import { FolderTree, Plus, Search } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { usePagedList } from "@/composables/usePagedList";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { usePermission } from "@/composables/usePermission";
import {
  useDeleteProductCategory,
  useMoveProductCategory,
  useProductCategories,
  useSaveProductCategory,
} from "@/queries/productCategories";
import type { CatalogFilter, ProductCategory } from "@/repositories/productCategories";
import { ContentWrap, Header } from "@/views/admin/components";
import ProductsNav from "../ProductsNav.vue";
import CategoryDialog from "./CategoryDialog.vue";
import CategoryRow from "./CategoryRow.vue";

const PAGE_SIZE = 20;

const { canCreate, canUpdate, canDelete } = usePermission("products");
const showInactive = ref(false);
const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [showInactive] });
const formOpen = ref(false);
const editing = ref<ProductCategory | null>(null);
const deleting = ref<ProductCategory | null>(null);

const filter = computed<CatalogFilter>(() => ({ search: debouncedSearch.value, includeInactive: showInactive.value }));
const listQuery = useProductCategories(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const saveMutation = useSaveProductCategory();
const moveMutation = useMoveProductCategory();
const deleteMutation = useDeleteProductCategory();

const openForm = (category: ProductCategory | null) => {
  editing.value = category;
  formOpen.value = true;
};

const setActive = async (category: ProductCategory, isActive: boolean) => {
  try {
    await saveMutation.mutateAsync({
      id: category.id,
      parentId: category.parentId,
      name: category.name,
      imageUrl: category.imageUrl ?? "",
      isActive,
    });
  } catch {
    // the mutation already showed the failure toast
  }
};

const move = (category: ProductCategory, direction: "up" | "down") => {
  moveMutation.mutate({ id: category.id, direction });
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
