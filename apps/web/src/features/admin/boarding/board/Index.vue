<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Home class="size-4 text-primary" />
      {{ $t("boarding.board.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <BoardingNav />
        <div class="flex flex-wrap items-center gap-2">
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <Button v-if="canCreate" :disabled="!branchId" @click="openNew()">
            <Plus class="mr-2 size-4" />
            {{ $t("boarding.stays.new") }}
          </Button>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 rounded-xl border bg-white p-3">
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('boarding.board.prev')" @click="date = addDays(date, -1)">
          <ChevronLeft class="size-4" />
        </Button>
        <Input v-model="date" type="date" class="h-9 w-44" />
        <Button variant="outline" size="icon" class="size-9" :aria-label="$t('boarding.board.next')" @click="date = addDays(date, 1)">
          <ChevronRight class="size-4" />
        </Button>
        <Button variant="outline" class="h-9" :disabled="date === todayKey()" @click="date = todayKey()">{{ $t("boarding.board.today") }}</Button>
        <Button variant="ghost" size="icon" class="ml-auto size-9" :aria-label="$t('boarding.board.refresh')" @click="boardQuery.refetch()">
          <RefreshCw class="size-4" :class="boardQuery.isFetching.value && 'animate-spin'" />
        </Button>
      </div>

      <BoardStats v-if="board" :counts="board.counts" />

      <div class="min-h-[16rem] flex-1 space-y-5 overflow-auto">
        <p v-if="boardQuery.isPending.value" class="p-8 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
        <p v-else-if="groups.length === 0" class="rounded-xl border bg-white p-8 text-center text-sm text-muted-foreground">
          {{ $t("boarding.board.empty") }}
          <router-link :to="{ name: 'boardingSettings' }" class="font-semibold text-primary underline">{{ $t("boarding.nav.settings") }}</router-link>
        </p>
        <section v-for="group in groups" :key="group.id" class="space-y-2">
          <h2 class="text-sm font-semibold">
            {{ group.name }}
            <span class="font-normal text-muted-foreground">· {{ group.kennels.length }}</span>
          </h2>
          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            <KennelCard
              v-for="kennel in group.kennels"
              :key="kennel.id"
              :kennel="kennel"
              :can-create="canCreate"
              :can-update="canUpdate"
              @open="openKennel(kennel)"
              @clean="markClean(kennel)"
            />
          </div>
        </section>
      </div>
    </div>

    <StayDialog v-if="branchId" v-model:open="dialogOpen" :branch-id="branchId" :stay="null" :prefill="prefill" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight, Home, Plus, RefreshCw } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import BoardingNav from "../BoardingNav.vue";
import { addDays, todayKey } from "../format";
import StayDialog from "../stay-dialog/StayDialog.vue";
import BoardStats from "./BoardStats.vue";
import KennelCard from "./KennelCard.vue";
import { useBoardingBoardView } from "./useBoardingBoard";

const { branches, branchId, selectBranch } = useCurrentBranch();
const { date, board, boardQuery, groups, canCreate, canUpdate, dialogOpen, prefill, openNew, openKennel, markClean } =
  useBoardingBoardView(branchId);
</script>
