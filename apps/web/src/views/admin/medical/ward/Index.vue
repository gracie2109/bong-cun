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
          @stop="stopOrder"
          @give="giveDose"
          @skip="skipDose = $event"
        />
      </div>
    </div>

    <OrderDialog :open="!!orderFor" :row="orderFor" @update:open="orderFor = null" />
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
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import MedicalNav from "../MedicalNav.vue";
import LogDialog from "./LogDialog.vue";
import OrderDialog from "./OrderDialog.vue";
import SkipDoseDialog from "./SkipDoseDialog.vue";
import { useWard } from "./useWard";
import WardCard from "./WardCard.vue";

const { branches, selectBranch } = useCurrentBranch();
const { branchId, query, rows, canUpdate, orderFor, logFor, skipDose, dischargeRow, giveDose, stopOrder, confirmDischarge } = useWard();
</script>
