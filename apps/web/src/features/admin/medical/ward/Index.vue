<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <BedDouble class="size-4 text-primary" />
      {{ $t("medical.ward.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <MedicalNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <Skeleton v-if="query.isPending.value" class="h-40 w-full rounded-xl" />
      <p v-else-if="rows.length === 0" class="rounded-xl border border-dashed bg-white p-8 text-center text-sm text-muted-foreground">
        {{ $t("medical.ward.empty") }}
      </p>
      <div v-else class="space-y-4">
        <WardCard
          v-for="row in rows"
          :key="row.stayPetId"
          :row="row"
          :can-update="canUpdate"
          @order="orderFor = row"
          @log="logFor = row"
          @discharge="dischargeRow = row"
          @edit="editOrder = $event"
          @replace="startReplace(row, $event)"
          @stop="stopOrder = $event"
          @give="giveDose"
          @skip="skipDose = $event"
        />
      </div>
    </div>

    <OrderDialog :open="!!orderFor" :row="orderFor" :replace-of="replaceOrder" @update:open="closeOrderDialog" />
    <OrderEditDialog :open="!!editOrder" :order="editOrder" @update:open="editOrder = null" />
    <StopOrderDialog :open="!!stopOrder" :order="stopOrder" @update:open="stopOrder = null" />
    <LogDialog :open="!!logFor" :row="logFor" @update:open="logFor = null" />
    <SkipDoseDialog :open="!!skipDose" :dose-id="skipDose?.id ?? null" @update:open="skipDose = null" />
    <ConfirmDialog
      :open="!!dischargeRow"
      :title="$t('medical.ward.dischargeTitle', { name: dischargeRow?.petName ?? '' })"
      :desc="$t('medical.ward.dischargeDesc')"
      :ok-btn="$t('medical.ward.discharge')"
      @handle-ok="confirmDischarge"
      @open-change="dischargeRow = null"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { BedDouble } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { ContentWrap, Header } from "@/features/admin/components";
import BranchPicker from "@/features/admin/pos/components/BranchPicker.vue";
import type { WardOrder, WardRow } from "@bongcun/core/medical";
import MedicalNav from "../MedicalNav.vue";
import LogDialog from "./LogDialog.vue";
import OrderDialog from "./OrderDialog.vue";
import OrderEditDialog from "./OrderEditDialog.vue";
import SkipDoseDialog from "./SkipDoseDialog.vue";
import StopOrderDialog from "./StopOrderDialog.vue";
import { useWard } from "./useWard";
import WardCard from "./WardCard.vue";

const { branches, selectBranch } = useCurrentBranch();
const {
  branchId, query, rows, canUpdate, orderFor, logFor, skipDose, dischargeRow, editOrder, replaceOrder, stopOrder,
  giveDose, confirmDischarge,
} = useWard();

// "Replace" opens the order dialog for the same pet, filled with the old order.
const startReplace = (row: WardRow, order: WardOrder) => {
  orderFor.value = row;
  replaceOrder.value = order;
};
const closeOrderDialog = () => {
  orderFor.value = null;
  replaceOrder.value = null;
};
</script>
