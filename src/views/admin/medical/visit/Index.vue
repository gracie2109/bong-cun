<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Stethoscope class="size-4 text-primary" />
      {{ $t("medical.detail.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <MedicalNav />
        <Button variant="outline" as-child>
          <router-link :to="{ name: 'medicalQueue' }"><ArrowLeft class="mr-2 size-4" />{{ $t("petCare.common.back") }}</router-link>
        </Button>
      </div>

      <Skeleton v-if="visitQuery.isPending.value" class="h-40 w-full rounded-xl" />
      <p v-else-if="!visit" class="rounded-xl border border-dashed bg-white p-8 text-center text-sm text-muted-foreground">
        {{ $t("medical.detail.notFound") }}
      </p>

      <template v-else>
        <VisitHeader :visit="visit" :can-update="canUpdate" :can-cancel="canCancel" @start="startVisit" @cancel="cancelOpen = true" />

        <div class="grid gap-5 xl:grid-cols-[22rem_minmax(0,1fr)]">
          <PetSidePanel v-if="visit.pet" :pet="visit.pet" :current-visit-id="visit.id" />
          <div class="rounded-xl border bg-white p-4">
            <Tabs default-value="record">
              <TabsList>
                <TabsTrigger value="record">{{ $t("medical.detail.tabRecord") }}</TabsTrigger>
                <TabsTrigger value="vaccines">{{ $t("medical.detail.tabVaccines") }}</TabsTrigger>
                <TabsTrigger value="items">{{ $t("medical.detail.tabItems") }} ({{ visit.items.length }})</TabsTrigger>
              </TabsList>
              <TabsContent value="record" class="pt-4">
                <RecordTab :visit="visit" :can-edit="canEditRecord" :can-add-addendum="canUpdate" />
              </TabsContent>
              <TabsContent value="vaccines" class="pt-4">
                <VaccinesTab :visit="visit" :can-update="canUpdate" />
              </TabsContent>
              <TabsContent value="items" class="pt-4">
                <ItemsTab :visit="visit" :can-update="canUpdate" />
              </TabsContent>
            </Tabs>
          </div>
        </div>

        <CancelVisitDialog v-model:open="cancelOpen" :code="visit.code" :busy="cancelling" @confirm="cancelVisit" />
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ArrowLeft, Stethoscope } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ContentWrap, Header } from "@/views/admin/components";
import MedicalNav from "../MedicalNav.vue";
import CancelVisitDialog from "./CancelVisitDialog.vue";
import ItemsTab from "./items/ItemsTab.vue";
import RecordTab from "./record/RecordTab.vue";
import PetSidePanel from "./side/PetSidePanel.vue";
import VaccinesTab from "./vaccines/VaccinesTab.vue";
import { useVisitDetail } from "./useVisitDetail";
import VisitHeader from "./VisitHeader.vue";

const { visitQuery, visit, canUpdate, canCancel, canEditRecord, cancelOpen, startVisit, cancelVisit, cancelling } = useVisitDetail();
</script>
