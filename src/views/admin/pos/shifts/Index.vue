<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Wallet class="size-4 text-primary" />
      {{ $t("pos.shifts.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <PosNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
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
                <th class="px-4 py-3 font-semibold">{{ $t("pos.shifts.code") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.shifts.cashier") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.shifts.openedAt") }}</th>
                <th class="px-4 py-3 font-semibold">{{ $t("pos.shifts.closedAt") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("pos.shift.openingCash") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("pos.shift.expectedCash") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("pos.shift.countedCash") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("pos.shifts.difference") }}</th>
                <th class="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              <template v-if="listQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="9" class="px-4 py-3"><Skeleton class="h-8 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="rows.length === 0">
                <td colspan="9" class="px-4 py-10 text-center text-muted-foreground">{{ $t("pos.shifts.empty") }}</td>
              </tr>
              <tr v-for="row in rows" :key="row.id" class="border-t">
                <td class="whitespace-nowrap px-4 py-3 font-semibold">
                  {{ row.code }}
                  <span
                    v-if="row.status === 'open'"
                    class="ml-1 rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"
                  >
                    {{ $t("pos.shifts.open") }}
                  </span>
                </td>
                <td class="px-4 py-3">{{ row.openedByName }}</td>
                <td class="whitespace-nowrap px-4 py-3">{{ dateTime(row.openedAt) }}</td>
                <td class="whitespace-nowrap px-4 py-3">
                  {{ dateTime(row.closedAt) }}
                  <span v-if="row.closedByName && row.closedByName !== row.openedByName" class="block text-xs text-muted-foreground">
                    {{ row.closedByName }}
                  </span>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{{ money(row.openingCash) }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{{ row.expectedCash === null ? "—" : money(row.expectedCash) }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{{ row.countedCash === null ? "—" : money(row.countedCash) }}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold" :class="differenceClass(row)">
                  {{ difference(row) === null ? "—" : money(difference(row)) }}
                </td>
                <td class="px-4 py-3 text-right">
                  <Button v-if="row.status === 'open' && canCloseShift(row)" size="sm" variant="outline" @click="closing = row">
                    {{ $t("pos.shift.close") }}
                  </Button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <CloseShiftDialog :open="!!closing" :shift="closing" @update:open="(open) => !open && (closing = null)" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { ChevronLeft, ChevronRight, Wallet } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePermission } from "@/composables/usePermission";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useShiftsList } from "@/queries/pos";
import type { CashShift } from "@/repositories/pos";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "../components/BranchPicker.vue";
import CloseShiftDialog from "../components/CloseShiftDialog.vue";
import PosNav from "../PosNav.vue";
import { dateTime, money } from "../format";

const PAGE_SIZE = 20;

const auth = useAuthStore();
const { canCreate, canUpdate } = usePermission("pos");
const { branches, branchId, selectBranch } = useCurrentBranch();
const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const closing = ref<CashShift | null>(null);

const listQuery = useShiftsList(branchId, page);
const rows = computed(() => listQuery.data.value?.rows ?? []);
const total = computed(() => listQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

watch(branchId, () => {
  page.pageIndex = INITIAL_PAGE_INDEX;
});

// Same rule as close_cash_shift: one's own shift, or anyone's with "pos: UPDATE".
const canCloseShift = (shift: CashShift) =>
  canUpdate.value || (canCreate.value && shift.openedBy === auth.session?.user.id);

/** Counted minus expected: positive = over, negative = short. */
const difference = (shift: CashShift): number | null =>
  shift.countedCash === null || shift.expectedCash === null ? null : shift.countedCash - shift.expectedCash;

const differenceClass = (shift: CashShift) => {
  const value = difference(shift);
  if (value === null || value === 0) return "";
  return value > 0 ? "text-amber-600" : "text-red-600";
};
</script>
