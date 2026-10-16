<template>
  <ul v-if="services.length > 0" class="divide-y divide-sage/15 border-y border-sage/15">
    <li v-for="service in services" :key="service.id" class="flex items-center justify-between gap-4 py-4">
      <span class="min-w-0">
        <span class="block font-semibold">{{ service.name }}</span>
        <span v-if="duration(service.durationMinutes)" class="mt-0.5 inline-flex items-center gap-1 text-sm text-muted-foreground">
          <Clock class="size-3.5" aria-hidden="true" />{{ duration(service.durationMinutes) }}
        </span>
      </span>
      <PriceDisplay class="shrink-0" size="sm" :amount="lowestPrice(service, species)" :from="priceLines(service, species).length > 1" />
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { Clock } from "lucide-vue-next";
import PriceDisplay from "@/components/shop/PriceDisplay.vue";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import type { SpaService, SpaSpecies } from "@bongcun/core/spa";
import { lowestPrice, priceLines } from "@bongcun/core/spa";

/** A short price list of spa services on the home page: name, time, and the lowest price. */
defineProps<{ services: SpaService[]; species: SpaSpecies }>();
const duration = useDurationLabel();
</script>
