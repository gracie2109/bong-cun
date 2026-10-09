<template>
  <div class="rounded-xl border bg-white p-4">
    <Tabs default-value="history">
      <TabsList>
        <TabsTrigger value="history">{{ $t("petCare.pets.detail.tabHistory") }}</TabsTrigger>
        <TabsTrigger value="upcoming">{{ $t("petCare.pets.detail.tabUpcoming") }}</TabsTrigger>
        <TabsTrigger value="boarding">{{ $t("petCare.pets.detail.tabBoarding") }}</TabsTrigger>
        <TabsTrigger value="notes">{{ $t("petCare.pets.detail.tabNotes") }}</TabsTrigger>
        <TabsTrigger value="medical" disabled>{{ $t("petCare.pets.detail.tabMedical") }}</TabsTrigger>
      </TabsList>
      <TabsContent v-for="tab in PLACEHOLDER_TABS" :key="tab" :value="tab">
        <p class="py-10 text-center text-sm text-muted-foreground">
          {{ $t("petCare.pets.detail.comingSoon") }}
        </p>
      </TabsContent>
    </Tabs>
  </div>
</template>

<script lang="ts" setup>
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

/** Tabs that have no content yet. */
const PLACEHOLDER_TABS = ["history", "upcoming", "boarding", "notes"];
</script>
