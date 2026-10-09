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

      <PagedTableCard v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
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
            <TableStateRows :colspan="9" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('pos.shifts.empty')" />
            <ShiftRow v-for="row in rows" :key="row.id" :shift="row" :can-close="canCloseShift(row)" @close="closing = row" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <CloseShiftDialog :open="!!closing" :shift="closing" @update:open="(open) => !open && (closing = null)" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ref, reactive, watch } from "vue";
import { Wallet } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePagedList } from "@/composables/usePagedList";
import { usePermission } from "@/composables/usePermission";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useShiftsList } from "@/queries/pos";
import type { CashShift } from "@/repositories/pos";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "../components/BranchPicker.vue";
import CloseShiftDialog from "../components/CloseShiftDialog.vue";
import PosNav from "../PosNav.vue";
import ShiftRow from "./ShiftRow.vue";

const PAGE_SIZE = 20;

const auth = useAuthStore();
const { canCreate, canUpdate } = usePermission("pos");
const { branches, branchId, selectBranch } = useCurrentBranch();
const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const closing = ref<CashShift | null>(null);

const listQuery = useShiftsList(branchId, page);
const { rows, total, pageCount } = usePagedList(listQuery, page);

watch(branchId, () => {
  page.pageIndex = INITIAL_PAGE_INDEX;
});

// Same rule as close_cash_shift: one's own shift, or anyone's with "pos: UPDATE".
const canCloseShift = (shift: CashShift) =>
  canUpdate.value || (canCreate.value && shift.openedBy === auth.session?.user.id);
</script>
