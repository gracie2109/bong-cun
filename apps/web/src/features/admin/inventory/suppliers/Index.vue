<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Truck class="size-4 text-primary" />
      {{ $t("inventory.suppliers.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <InventoryNav />
        <div class="flex flex-wrap items-center gap-2">
          <Button v-if="canCreate" @click="openForm(null)">
            <Plus class="mr-2 size-4" />
            {{ $t("inventory.suppliers.add") }}
          </Button>
        </div>
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('inventory.suppliers.searchPlaceholder')"
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
            <Switch v-model:checked="draft.showArchived" />
            {{ $t("inventory.suppliers.showArchived") }}
          </label>
        </template>
        <template #actions>
          <ExportMenu :exporter="exporter" compact />
          <ImportButton :allowed="canImport" compact @click="importOpen = true" />
        </template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.suppliers.name") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.suppliers.phone") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.suppliers.taxCode") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.suppliers.address") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('inventory.suppliers.empty')" />
            <SupplierRow v-for="row in rows" :key="row.id" :supplier="row" :can-update="canUpdate" @edit="openForm" @set-active="setActive" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <SupplierFormSheet v-model:open="formOpen" :supplier="editing" />
    <SuppliersImportDialog v-if="canImport" v-model:open="importOpen" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus, Truck } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ImportButton from "@/components/common/data-io/ImportButton.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { usePagedList } from "@/composables/usePagedList";
import { useListFilters } from "@/composables/useListFilters";
import { usePermission } from "@/composables/usePermission";
import { useSaveSupplier, useSuppliersList } from "@/queries/inventory";
import type { Supplier, SupplierFilter } from "@bongcun/supabase/inventory";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import InventoryNav from "../InventoryNav.vue";
import SupplierFormSheet from "./SupplierFormSheet.vue";
import SuppliersImportDialog from "./import/SuppliersImportDialog.vue";
import SupplierRow from "./SupplierRow.vue";
import { useSuppliersExport } from "./useSuppliersExport";

const PAGE_SIZE = 20;

const { canCreate, canUpdate } = usePermission("inventory");
const { search, debouncedSearch, page, applied, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } =
  useListFilters({ pageSize: PAGE_SIZE, defaults: { showArchived: false } });
const formOpen = ref(false);
const editing = ref<Supplier | null>(null);

const filter = computed<SupplierFilter>(() => ({ search: debouncedSearch.value, includeArchived: applied.value.showArchived }));
const exporter = useSuppliersExport(filter);
const canImport = computed(() => useAuthStore().can("inventory", "IMPORT"));
const importOpen = ref(false);
const listQuery = useSuppliersList(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const saveMutation = useSaveSupplier();

const openForm = (supplier: Supplier | null) => {
  editing.value = supplier;
  formOpen.value = true;
};

const setActive = async (supplier: Supplier, isActive: boolean) => {
  try {
    await saveMutation.mutateAsync({ id: supplier.id, input: { ...supplier, isActive } });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
