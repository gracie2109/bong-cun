<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ClipboardList class="size-4 text-primary" />
      {{ $t("boarding.detail.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <BoardingNav />
        <Button variant="outline" as-child>
          <router-link :to="{ name: 'boardingStays' }"><ArrowLeft class="mr-2 size-4" />{{ $t("petCare.common.back") }}</router-link>
        </Button>
      </div>

      <Skeleton v-if="stayQuery.isPending.value" class="h-40 w-full rounded-xl" />
      <p v-else-if="!stay" class="rounded-xl border border-dashed bg-white p-8 text-center text-sm text-muted-foreground">
        {{ $t("boarding.detail.notFound") }}
      </p>

      <template v-else>
        <StayHeader
          :stay="stay"
          :can-create="canCreate"
          :can-update="canUpdate"
          @edit="editOpen = true"
          @check-in="checkInOpen = true"
          @extend="extendOpen = true"
          @check-out="checkOutOpen = true"
          @no-show="markNoShow"
        />

        <InpatientNotice v-if="stay.kind === 'inpatient'" :stay="stay" />

        <section class="grid gap-3 lg:grid-cols-2">
          <PetCard
            v-for="pet in stay.pets"
            :key="pet.id"
            :pet="pet"
            :checked-in="stay.checkedInAt !== null"
            :can-move="canUpdate && pet.status === 'active' && (stay.status === 'booked' || stay.status === 'checked_in')"
            @move="movePet = pet"
          />
        </section>

        <Tabs default-value="care">
          <TabsList>
            <TabsTrigger value="care">{{ $t("boarding.detail.tabCare") }} ({{ stay.careLogs.length }})</TabsTrigger>
            <TabsTrigger value="extras">{{ $t("boarding.detail.tabExtras") }}</TabsTrigger>
            <TabsTrigger value="money">{{ $t("boarding.detail.tabMoney") }}</TabsTrigger>
          </TabsList>
          <TabsContent value="care" class="mt-4">
            <CareLogTab :logs="stay.careLogs" :pets="activePets" :can-write="isIn && canCreate" />
          </TabsContent>
          <TabsContent value="extras" class="mt-4">
            <ExtrasTab :charges="stay.charges" :pets="activePets" :can-add="isIn && canCreate && stay.kind !== 'inpatient'" :can-remove="canUpdate" />
          </TabsContent>
          <TabsContent value="money" class="mt-4">
            <ChargesTab :stay="stay" />
          </TabsContent>
        </Tabs>

        <StayDialog v-model:open="editOpen" :branch-id="stay.branchId" :stay="stay" />
        <CheckInDialog v-model:open="checkInOpen" :stay="stay" />
        <ExtendDialog v-model:open="extendOpen" :stay="stay" />
        <MoveKennelDialog v-if="movePet" :open="true" :stay="stay" :pet="movePet" @update:open="movePet = null" />
        <CheckOutDialog v-model:open="checkOutOpen" :stay="stay" />
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ArrowLeft, ClipboardList } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ContentWrap, Header } from "@/features/admin/components";
import BoardingNav from "../BoardingNav.vue";
import StayDialog from "../stay-dialog/StayDialog.vue";
import CareLogTab from "./CareLogTab.vue";
import ChargesTab from "./ChargesTab.vue";
import CheckInDialog from "./CheckInDialog.vue";
import CheckOutDialog from "./CheckOutDialog.vue";
import ExtendDialog from "./ExtendDialog.vue";
import ExtrasTab from "./ExtrasTab.vue";
import MoveKennelDialog from "./MoveKennelDialog.vue";
import InpatientNotice from "./InpatientNotice.vue";
import PetCard from "./PetCard.vue";
import StayHeader from "./StayHeader.vue";
import { useStayDetail } from "./useStayDetail";

const {
  stayQuery, stay, activePets, isIn, canCreate, canUpdate,
  editOpen, checkInOpen, extendOpen, checkOutOpen, movePet, markNoShow,
} = useStayDetail();
</script>
