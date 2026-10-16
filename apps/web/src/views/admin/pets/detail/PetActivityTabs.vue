<template>
  <div class="rounded-xl border bg-white p-4">
    <Tabs default-value="history">
      <TabsList>
        <TabsTrigger value="history">{{ $t("petCare.pets.detail.tabHistory") }}</TabsTrigger>
        <TabsTrigger value="upcoming">{{ $t("petCare.pets.detail.tabUpcoming") }}</TabsTrigger>
        <TabsTrigger value="boarding">{{ $t("petCare.pets.detail.tabBoarding") }}</TabsTrigger>
        <TabsTrigger value="notes">{{ $t("petCare.pets.detail.tabNotes") }}</TabsTrigger>
        <TabsTrigger v-if="canViewMedical" value="vaccines">{{ $t("petCare.pets.detail.tabVaccines") }}</TabsTrigger>
        <TabsTrigger v-if="canViewMedical" value="medical">{{ $t("petCare.pets.detail.tabMedical") }}</TabsTrigger>
      </TabsList>
      <TabsContent v-if="canViewMedical" value="vaccines">
        <VaccinationBookTab :pet-id="petId" />
      </TabsContent>
      <TabsContent v-if="canViewMedical" value="medical">
        <MedicalHistoryTab :pet-id="petId" />
      </TabsContent>
      <TabsContent v-for="tab in PLACEHOLDER_TABS" :key="tab" :value="tab">
        <p class="py-10 text-center text-sm text-muted-foreground">
          {{ $t("petCare.pets.detail.comingSoon") }}
        </p>
      </TabsContent>
    </Tabs>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useAuthStore } from "@/stores";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import MedicalHistoryTab from "./medical/MedicalHistoryTab.vue";
import VaccinationBookTab from "./medical/VaccinationBookTab.vue";

defineProps<{ petId: string }>();
const canViewMedical = computed(() => useAuthStore().can("medical", "VIEW"));

/** Tabs that have no content yet. */
const PLACEHOLDER_TABS = ["history", "upcoming", "boarding", "notes"];
</script>
