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
        <Button v-if="canCreate" @click="openForm(null)">
          <Plus class="mr-2 size-4" />
          {{ $t("inventory.suppliers.add") }}
        </Button>
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('inventory.suppliers.searchPlaceholder')" />
        </div>
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model:checked="showArchived" />
          {{ $t("inventory.suppliers.showArchived") }}
        </label>
      </div>

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
            <TableStateRows :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('inventory.suppliers.empty')" />
            <SupplierRow v-for="row in rows" :key="row.id" :supplier="row" :can-update="canUpdate" @edit="openForm" @set-active="setActive" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <SupplierFormSheet v-model:open="formOpen" :supplier="editing" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus, Search, Truck } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { usePagedList } from "@/composables/usePagedList";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { usePermission } from "@/composables/usePermission";
import { useSaveSupplier, useSuppliersList } from "@/queries/inventory";
import type { Supplier, SupplierFilter } from "@/repositories/inventory";
import { ContentWrap, Header } from "@/views/admin/components";
import InventoryNav from "../InventoryNav.vue";
import SupplierFormSheet from "./SupplierFormSheet.vue";
import SupplierRow from "./SupplierRow.vue";

const PAGE_SIZE = 20;

const { canCreate, canUpdate } = usePermission("inventory");
const showArchived = ref(false);
const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [showArchived] });
const formOpen = ref(false);
const editing = ref<Supplier | null>(null);

const filter = computed<SupplierFilter>(() => ({ search: debouncedSearch.value, includeArchived: showArchived.value }));
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
