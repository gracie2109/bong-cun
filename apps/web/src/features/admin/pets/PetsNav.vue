<template>
  <nav class="flex flex-wrap gap-1 rounded-xl border bg-white p-1">
    <router-link
      v-for="tab in tabs"
      :key="tab.name"
      :to="{ name: tab.name }"
      class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
      :class="
        isActive(tab.name)
          ? 'bg-primary text-primary-foreground'
          : 'text-muted-foreground hover:bg-muted'
      "
    >
      <Icon :icon="tab.icon" class="size-4" />
      {{ $t(tab.label) }}
    </router-link>
  </nav>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { useRoute } from "vue-router";

const route = useRoute();

const tabs = [
  { name: "pets", icon: "lucide:paw-print", label: "petCare.nav.profiles" },
  { name: "petSpecies", icon: "lucide:dog", label: "petCare.nav.species" },
  { name: "petService", icon: "carbon:settings-services", label: "petCare.nav.services" },
  { name: "petPrices", icon: "lucide:banknote", label: "petCare.nav.prices" },
  { name: "petServiceCombo", icon: "lucide:layers-2", label: "petCare.nav.combos" },
];

// A pet's detail page belongs to the profiles tab.
const isActive = (name: string): boolean =>
  route.name === name || (name === "pets" && route.name === "petDetail");
</script>
