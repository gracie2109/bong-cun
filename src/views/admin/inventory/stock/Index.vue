<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Boxes class="size-4 text-primary" />
      {{ $t("inventory.stock.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <InventoryNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <button
          v-for="chip in ALERTS"
          :key="chip.status"
          type="button"
          class="flex items-center justify-between gap-3 rounded-xl border bg-white p-4 text-left transition-colors hover:border-primary"
          :class="status === chip.status ? 'border-primary ring-1 ring-primary' : ''"
          :aria-pressed="status === chip.status"
          @click="status = status === chip.status ? 'all' : chip.status"
        >
          <span>
            <span class="block text-sm text-muted-foreground">
              {{ $t(`inventory.stock.alerts.${chip.status}`, { days: expiryDays }) }}
            </span>
            <span class="text-2xl font-bold" :class="(alerts?.[chip.status] ?? 0) > 0 ? chip.tone : ''">
              {{ alerts?.[chip.status] ?? "–" }}
            </span>
          </span>
          <component :is="chip.icon" class="size-6 text-muted-foreground" />
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('products.searchPlaceholder')" />
        </div>
        <Select v-model="status">
          <SelectTrigger class="w-48" :aria-label="$t('inventory.stock.filter')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="item in STOCK_STATUSES" :key="item" :value="item">
              {{ $t(`inventory.stock.status.${item}`) }}
            </SelectItem>
          </SelectContent>
        </Select>
        <Select v-model="expiryWindow">
          <SelectTrigger class="w-44" :aria-label="$t('inventory.stock.expiryWindow')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="days in EXPIRY_WINDOWS" :key="days" :value="String(days)">
              {{ $t("inventory.stock.withinDays", { days }) }}
            </SelectItem>
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
                <th class="px-4 py-3 font-semibold">{{ $t("products.col.product") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.sellable") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.expired") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("inventory.stock.nextExpiry") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.min") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.value") }}</th>
              </tr>
            </thead>
            <tbody>
              <template v-if="listQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="6" class="px-4 py-3"><Skeleton class="h-8 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="rows.length === 0">
                <td colspan="6" class="px-4 py-10 text-center text-muted-foreground">{{ $t("inventory.stock.empty") }}</td>
              </tr>
              <tr
                v-for="row in rows"
                :key="row.productId"
                class="cursor-pointer border-t hover:bg-muted/40"
                :class="row.isActive ? '' : 'opacity-60'"
                @click="openRow = row"
              >
                <td class="px-4 py-3">
                  <p class="font-semibold">{{ row.name }}</p>
                  <p class="text-xs text-muted-foreground">{{ [row.sku, row.unit].filter(Boolean).join(" · ") }}</p>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-right">
                  <span class="font-semibold" :class="sellableTone(row)">{{ qty(row.sellable) }}</span>
                  <span v-if="row.minQty !== null && row.sellable < row.minQty" class="ml-2 rounded-full bg-amber-50 px-2 py-0.5 text-[10px] font-semibold text-amber-700">
                    {{ $t("inventory.stock.status.low") }}
                  </span>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-right" :class="row.expired > 0 ? 'font-semibold text-red-600' : 'text-muted-foreground'">
                  {{ row.expired > 0 ? qty(row.expired) : "—" }}
                </td>
                <td class="whitespace-nowrap px-4 py-3">
                  <template v-if="row.nextExpiry">
                    {{ day(row.nextExpiry) }}
                    <span
                      class="ml-1 text-xs"
                      :class="daysUntil(row.nextExpiry) < expiryDays ? 'font-semibold text-amber-700' : 'text-muted-foreground'"
                    >
                      {{ $t("inventory.stock.inDays", { n: daysUntil(row.nextExpiry) }) }}
                    </span>
                  </template>
                  <span v-else class="text-muted-foreground">—</span>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-right text-muted-foreground">{{ row.minQty === null ? "—" : qty(row.minQty) }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{{ money(row.stockValue) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <StockProductSheet :row="openRow" :branch-id="branchId" :expiry-days="expiryDays" @close="openRow = null" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { AlarmClock, Boxes, ChevronLeft, ChevronRight, PackageX, Search, TrendingDown, TriangleAlert } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useStockAlertCounts, useStockSummary } from "@/queries/inventory";
import {
  EXPIRY_WINDOWS,
  STOCK_STATUSES,
  type StockFilter,
  type StockRow,
  type StockStatus,
} from "@/repositories/inventory";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import { money } from "@/views/admin/pos/format";
import { day, daysUntil, qty } from "../format";
import InventoryNav from "../InventoryNav.vue";
import StockProductSheet from "./StockProductSheet.vue";

const PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 500;
const DEFAULT_EXPIRY_DAYS = 60;
const ALERTS = [
  { status: "low", icon: TrendingDown, tone: "text-amber-700" },
  { status: "out", icon: PackageX, tone: "text-red-600" },
  { status: "expiring", icon: AlarmClock, tone: "text-amber-700" },
  { status: "expired", icon: TriangleAlert, tone: "text-red-600" },
] as const;

const { branches, branchId, selectBranch } = useCurrentBranch();
const search = ref("");
const status = ref<StockStatus>("all");
const expiryWindow = ref(String(DEFAULT_EXPIRY_DAYS));
const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const openRow = ref<StockRow | null>(null);
const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);
const expiryDays = computed(() => Number(expiryWindow.value));

const filter = computed<StockFilter | null>(() =>
  branchId.value
    ? { branchId: branchId.value, search: debouncedSearch.value, status: status.value, expiryDays: expiryDays.value }
    : null
);

const listQuery = useStockSummary(page, filter);
const alertsQuery = useStockAlertCounts(branchId, expiryDays);
const alerts = computed(() => alertsQuery.data.value);
const rows = computed(() => listQuery.data.value?.rows ?? []);
const total = computed(() => listQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

// Keep the open sheet in step with the list after a change (minimum stock, a receipt...).
watch(rows, (list) => {
  if (openRow.value) openRow.value = list.find((row) => row.productId === openRow.value?.productId) ?? openRow.value;
});

watch([debouncedSearch, status, expiryDays, branchId], () => {
  page.pageIndex = INITIAL_PAGE_INDEX;
});

const sellableTone = (row: StockRow) => {
  if (row.sellable === 0) return "text-red-600";
  if (row.minQty !== null && row.sellable < row.minQty) return "text-amber-700";
  return "";
};
</script>
