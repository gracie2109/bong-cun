<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Receipt class="size-4 text-primary" />
      {{ $t("pos.invoices.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <PosNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('pos.invoices.searchPlaceholder')" />
        </div>
        <Select v-model="period">
          <SelectTrigger class="w-40" :aria-label="$t('pos.invoices.period')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="option in PERIODS" :key="option" :value="option">{{ $t(`pos.invoices.periods.${option}`) }}</SelectItem>
          </SelectContent>
        </Select>
        <Select v-model="status">
          <SelectTrigger class="w-40" :aria-label="$t('pos.invoices.status')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem value="paid">{{ $t("pos.status.paid") }}</SelectItem>
            <SelectItem value="cancelled">{{ $t("pos.status.cancelled") }}</SelectItem>
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
        <div class="table-scroll">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.code") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.time") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.receipt.customer") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.receipt.cashier") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("pos.total") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.status") }}</th>
              </tr>
            </thead>
            <tbody>
              <template v-if="listQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="6" class="px-4 py-3"><Skeleton class="h-8 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="rows.length === 0">
                <td colspan="6" class="px-4 py-10 text-center text-muted-foreground">{{ $t("pos.invoices.empty") }}</td>
              </tr>
              <tr
                v-for="row in rows"
                :key="row.id"
                class="cursor-pointer border-t hover:bg-muted/40"
                :class="row.status === 'cancelled' ? 'text-muted-foreground' : ''"
                @click="openId = row.id"
              >
                <td class="px-4 py-3 font-semibold">{{ row.code }}</td>
                <td class="whitespace-nowrap px-4 py-3">{{ dateTime(row.createdAt) }}</td>
                <td class="px-4 py-3">
                  {{ row.customerName ?? $t("pos.walkIn") }}
                  <span v-if="row.customerPhone" class="block text-xs text-muted-foreground">{{ row.customerPhone }}</span>
                </td>
                <td class="px-4 py-3">{{ row.cashierName }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold" :class="row.status === 'cancelled' ? 'line-through' : ''">
                  {{ money(row.total) }}
                </td>
                <td class="px-4 py-3">
                  <span
                    class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
                    :class="row.status === 'paid' ? 'bg-primary/10 text-primary' : 'bg-red-50 text-red-600'"
                  >
                    {{ $t(`pos.status.${row.status}`) }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <InvoiceSheet :invoice-id="openId" :branch="branch" @close="openId = undefined" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { ChevronLeft, ChevronRight, Receipt, Search } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useInvoicesList } from "@/queries/pos";
import type { InvoiceFilter, InvoiceStatus } from "@/repositories/pos";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "../components/BranchPicker.vue";
import PosNav from "../PosNav.vue";
import { dateTime, money } from "../format";
import InvoiceSheet from "./InvoiceSheet.vue";

const ALL = "all";
const PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 500;
const PERIODS = ["today", "week", "month", "all"] as const;
type Period = (typeof PERIODS)[number];

const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const search = ref("");
const period = ref<Period>("today");
const status = ref<string>(ALL);
const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const openId = ref<string>();
const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);

const periodStart = (value: Period): string | undefined => {
  if (value === "all") return undefined;
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  if (value === "week") start.setDate(start.getDate() - 6);
  if (value === "month") start.setDate(start.getDate() - 29);
  return start.toISOString();
};

const filter = computed<InvoiceFilter | null>(() =>
  branchId.value
    ? {
        branchId: branchId.value,
        from: periodStart(period.value),
        status: status.value === ALL ? undefined : (status.value as InvoiceStatus),
        search: debouncedSearch.value,
      }
    : null
);

const listQuery = useInvoicesList(page, filter);
const rows = computed(() => listQuery.data.value?.rows ?? []);
const total = computed(() => listQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

watch([debouncedSearch, period, status, branchId], () => {
  page.pageIndex = INITIAL_PAGE_INDEX;
});
</script>
