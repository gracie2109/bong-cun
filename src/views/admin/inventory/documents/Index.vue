<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ClipboardList class="size-4 text-primary" />
      {{ $t("inventory.documents.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <InventoryNav />
        <div class="flex flex-wrap items-center gap-2">
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <DropdownMenu v-if="canCreate">
            <DropdownMenuTrigger as-child>
              <Button>
                <Plus class="mr-2 size-4" />
                {{ $t("inventory.documents.new") }}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem v-for="type in DOC_TYPES" :key="type" @click="openNew(type)">
                {{ $t(`inventory.documents.types.${type}`) }}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <DocumentsFilterBar v-model:search="search" v-model:doc-type="docType" v-model:status="status" />

      <PagedTableCard v-model:page="page.pageIndex" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.documents.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.documents.type") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.time") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.documents.supplierOrNote") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.documents.createdBy") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.documents.value") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.status") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="7" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('inventory.documents.empty')" />
            <DocumentRow v-for="row in rows" :key="row.id" :row="row" @open="openExisting(row.id)" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <DocumentSheet
      :document-id="openId"
      :new-type="newType"
      :branch-id="branchId"
      @saved="(id) => openExisting(id)"
      @close="closeSheet"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { ClipboardList, Plus } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { usePagedList } from "@/composables/usePagedList";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePermission } from "@/composables/usePermission";
import { useStockDocuments } from "@/queries/inventory";
import { DOC_TYPES, type DocType } from "@/repositories/inventory";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import InventoryNav from "../InventoryNav.vue";
import DocumentRow from "./DocumentRow.vue";
import DocumentSheet from "./DocumentSheet.vue";
import DocumentsFilterBar from "./DocumentsFilterBar.vue";
import { useDocumentsFilters } from "./useDocumentsFilters";

const { branches, branchId, selectBranch } = useCurrentBranch();
const { canCreate } = usePermission("inventory");
const { search, docType, status, page, filter } = useDocumentsFilters(branchId);

const openId = ref<string>();
const newType = ref<DocType>();

const listQuery = useStockDocuments(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const openNew = (type: DocType) => {
  openId.value = undefined;
  newType.value = type;
};

const openExisting = (id: string) => {
  newType.value = undefined;
  openId.value = id;
};

const closeSheet = () => {
  openId.value = undefined;
  newType.value = undefined;
};
</script>
