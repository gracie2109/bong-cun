<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Stethoscope class="size-4 text-primary" />
      {{ $t("medical.queue.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <MedicalNav />
        <div class="flex flex-wrap items-center gap-2">
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <Button v-if="canCreate" :disabled="!branchId" @click="openCheckIn()">
            <Plus class="mr-2 size-4" />
            {{ $t("medical.queue.checkIn") }}
          </Button>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 rounded-xl border bg-white p-3">
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('medical.queue.prev')" @click="date = addDays(date, -1)">
          <ChevronLeft class="size-4" />
        </Button>
        <Input v-model="date" type="date" class="h-9 w-44" />
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('medical.queue.next')" @click="date = addDays(date, 1)">
          <ChevronRight class="size-4" />
        </Button>
        <Button variant="outline" class="h-9" :disabled="date === todayKey()" @click="date = todayKey()">{{ $t("medical.queue.today") }}</Button>
        <Button variant="ghost" size="icon" class="ml-auto size-9" :aria-label="$t('medical.queue.refresh')" @click="queueQuery.refetch()">
          <RefreshCw class="size-4" :class="queueQuery.isFetching.value && 'animate-spin'" />
        </Button>
      </div>

      <p v-if="queueQuery.isPending.value" class="p-8 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
      <div v-else class="grid min-h-[16rem] flex-1 gap-3 lg:grid-cols-3">
        <QueueColumn :title="$t('medical.queue.waiting')" :count="waiting.length">
          <QueueCard
            v-for="visit in waiting"
            :key="visit.id"
            :visit="visit"
            :can-start="canUpdate && visit.status === 'waiting'"
            :can-check-in="canCreate && visit.status === 'scheduled'"
            :can-no-show="canDelete && visit.status === 'scheduled'"
            @open="openVisit(visit)"
            @start="takeCase(visit)"
            @check-in="openCheckIn(visit)"
            @no-show="markNoShow(visit)"
          />
        </QueueColumn>
        <QueueColumn :title="$t('medical.queue.inProgress')" :count="inProgress.length">
          <QueueCard v-for="visit in inProgress" :key="visit.id" :visit="visit" :can-start="false" :can-check-in="false" :can-no-show="false" @open="openVisit(visit)" />
        </QueueColumn>
        <QueueColumn :title="$t('medical.queue.done')" :count="done.length">
          <QueueCard v-for="visit in done" :key="visit.id" :visit="visit" :can-start="false" :can-check-in="false" :can-no-show="false" @open="openVisit(visit)" />
        </QueueColumn>
      </div>
    </div>

    <CheckInDialog v-if="branchId" v-model:open="checkInOpen" :branch-id="branchId" :visit="checkInVisit" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight, Plus, RefreshCw, Stethoscope } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import CheckInDialog from "../check-in/CheckInDialog.vue";
import { addDays, todayKey } from "../format";
import MedicalNav from "../MedicalNav.vue";
import QueueCard from "./QueueCard.vue";
import QueueColumn from "./QueueColumn.vue";
import { useMedicalQueueView } from "./useMedicalQueue";

const { branches, branchId, selectBranch } = useCurrentBranch();
const {
  queueQuery, waiting, inProgress, done, date, canCreate, canUpdate, canDelete,
  checkInOpen, checkInVisit, openCheckIn, openVisit, takeCase, markNoShow,
} = useMedicalQueueView(branchId);
</script>
