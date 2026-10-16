<template>
  <ul class="divide-y overflow-hidden rounded-3xl border bg-white">
    <li v-for="service in services" :key="service.id" class="grid gap-3 p-5 sm:grid-cols-[1fr_auto] sm:gap-8 sm:p-6">
      <div class="min-w-0">
        <h3 class="text-base font-bold">{{ service.name }}</h3>
        <p v-if="duration(service.durationMinutes)" class="mt-1 inline-flex items-center gap-1 text-xs text-muted-foreground">
          <Clock class="size-3.5" aria-hidden="true" />{{ duration(service.durationMinutes) }}
        </p>
        <p v-if="service.description" class="mt-2 text-sm text-muted-foreground">{{ service.description }}</p>
      </div>
      <div class="sm:min-w-[220px]">
        <p v-if="lines(service).length === 0" class="text-sm font-medium text-muted-foreground sm:text-right">{{ $t("client.spa.contactPrice") }}</p>
        <dl v-else class="space-y-1.5 rounded-2xl bg-secondary/60 p-3 text-sm">
          <div v-for="line in lines(service)" :key="line.key" class="flex items-baseline justify-between gap-4">
            <dt class="text-muted-foreground">{{ line.label || $t("client.spa.price") }}</dt>
            <dd class="font-bold tabular-nums">{{ formatPrice(line.price) }}</dd>
          </div>
        </dl>
      </div>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { Clock } from "lucide-vue-next";
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import { formatPrice } from "@/lib/utils";
import type { SpaService, SpaSpecies } from "@bongcun/core/spa";
import { priceLines } from "@bongcun/core/spa";

const props = defineProps<{ services: SpaService[]; species: SpaSpecies }>();

const duration = useDurationLabel();
const lines = (service: SpaService) => priceLines(service, props.species);
</script>
