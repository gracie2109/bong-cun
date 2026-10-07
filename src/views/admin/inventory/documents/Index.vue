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

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('inventory.documents.searchPlaceholder')" />
        </div>
        <Select v-model="docType">
          <SelectTrigger class="w-44" :aria-label="$t('inventory.documents.type')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem v-for="type in DOC_TYPES" :key="type" :value="type">{{ $t(`inventory.documents.types.${type}`) }}</SelectItem>
          </SelectContent>
        </Select>
        <Select v-model="status">
          <SelectTrigger class="w-40" :aria-label="$t('pos.invoices.status')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem v-for="item in DOC_STATUSES" :key="item" :value="item">{{ $t(`inventory.documents.status.${item}`) }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="overflow-hidden rounded-xl border bg-white">
        <div class="flex items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
          <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
            {{ $t("petCare.common.showing", { count: rows.length, total }) }}
          </span>
          <div class="flex items-center gap-1 text-xs text-muted-foreground">
            <Button variant="ghost" size="icon" class="size-7" :disabled="page.pageIndex <= 1" @click="page.pageIndex -= 1">
              <ChevronLeft class="size-4" />
            </Button>
            <span>{{ $t("petCare.common.pageOf", { page: page.pageIndex, pages: pageCount }) }}</span>
            <Button variant="ghost" size="icon" class="size-7" :disabled="page.pageIndex >= pageCount" @click="page.pageIndex += 1">
              <ChevronRight class="size-4" />
            </Button>
          </div>
        </div>
        <div class="overflow-x-auto">
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
              <template v-if="listQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="7" class="px-4 py-3"><Skeleton class="h-8 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="rows.length === 0">
                <td colspan="7" class="px-4 py-10 text-center text-muted-foreground">{{ $t("inventory.documents.empty") }}</td>
              </tr>
              <tr
                v-for="row in rows"
                :key="row.id"
                class="cursor-pointer border-t hover:bg-muted/40"
                :class="row.status === 'cancelled' ? 'text-muted-foreground' : ''"
                @click="openExisting(row.id)"
              >
                <td class="px-4 py-3 font-semibold">{{ row.code }}</td>
                <td class="px-4 py-3">{{ $t(`inventory.documents.types.${row.docType}`) }}</td>
                <td class="whitespace-nowrap px-4 py-3">{{ dateTime(row.postedAt ?? row.createdAt) }}</td>
                <td class="max-w-64 px-4 py-3">
                  <span class="line-clamp-1">{{ row.supplierName ?? row.note ?? "—" }}</span>
                  <span v-if="row.supplierRef" class="block text-xs text-muted-foreground">{{ row.supplierRef }}</span>
                </td>
                <td class="px-4 py-3">{{ row.postedByName ?? row.createdByName }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ row.status === "draft" ? "—" : money(row.totalCost) }}</td>
                <td class="px-4 py-3">
                  <span class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="STATUS_TONE[row.status]">
                    {{ $t(`inventory.documents.status.${row.status}`) }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
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
import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { ChevronLeft, ChevronRight, ClipboardList, Plus, Search } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePermission } from "@/composables/usePermission";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useStockDocuments } from "@/queries/inventory";
import {
  DOC_STATUSES,
  DOC_TYPES,
  type DocStatus,
  type DocType,
  type StockDocumentFilter,
} from "@/repositories/inventory";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import { dateTime, money } from "@/views/admin/pos/format";
import InventoryNav from "../InventoryNav.vue";
import DocumentSheet from "./DocumentSheet.vue";

const ALL = "all";
const PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 500;
const STATUS_TONE: Record<DocStatus, string> = {
  draft: "bg-amber-50 text-amber-700",
  posted: "bg-primary/10 text-primary",
  cancelled: "bg-red-50 text-red-600",
};

const { branches, branchId, selectBranch } = useCurrentBranch();
const { canCreate } = usePermission("inventory");
const search = ref("");
const docType = ref<string>(ALL);
const status = ref<string>(ALL);
const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const openId = ref<string>();
const newType = ref<DocType>();
const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);

const filter = computed<StockDocumentFilter | null>(() =>
  branchId.value
    ? {
        branchId: branchId.value,
        docType: docType.value === ALL ? undefined : (docType.value as DocType),
        status: status.value === ALL ? undefined : (status.value as DocStatus),
        search: debouncedSearch.value,
      }
    : null
);

const listQuery = useStockDocuments(page, filter);
const rows = computed(() => listQuery.data.value?.rows ?? []);
const total = computed(() => listQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

watch([debouncedSearch, docType, status, branchId], () => {
  page.pageIndex = INITIAL_PAGE_INDEX;
});

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
