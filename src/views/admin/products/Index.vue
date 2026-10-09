<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Package class="size-4 text-primary" />
      {{ $t("products.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("products.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("products.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="openForm(null)">
          <Plus class="mr-2 size-4" />
          {{ $t("products.add") }}
        </Button>
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('products.searchPlaceholder')" />
        </div>
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model:checked="showArchived" />
          {{ $t("products.showArchived") }}
        </label>
      </div>

      <PagedTableCard v-model:page="page.pageIndex" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.product") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.variants") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("products.form.sku") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("products.form.price") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('products.empty')" />
            <ProductRow v-for="row in rows" :key="row.id" :group="row" :can-update="canUpdate" @edit="openForm" @set-active="setActive" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <ProductGroupSheet v-model:open="formOpen" :group-id="editingId" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Package, Plus, Search } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { usePagedList } from "@/composables/usePagedList";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { usePermission } from "@/composables/usePermission";
import { useProductGroups, useSetProductGroupActive } from "@/queries/products";
import type { ProductFilter, ProductGroup } from "@/repositories/products";
import { ContentWrap, Header } from "@/views/admin/components";
import ProductGroupSheet from "./ProductGroupSheet.vue";
import ProductRow from "./ProductRow.vue";

const PAGE_SIZE = 20;

const { canCreate, canUpdate } = usePermission("products");
const showArchived = ref(false);
const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [showArchived] });
const formOpen = ref(false);
const editingId = ref<string | null>(null);

const filter = computed<ProductFilter>(() => ({ search: debouncedSearch.value, includeArchived: showArchived.value }));
const listQuery = useProductGroups(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
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
