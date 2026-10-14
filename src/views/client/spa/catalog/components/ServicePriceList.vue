<template>
  <ul class="divide-y rounded-xl border bg-white">
    <li v-for="service in services" :key="service.id" class="flex flex-col gap-2 p-4 sm:flex-row sm:items-start sm:justify-between">
      <div class="min-w-0">
        <h3 class="font-semibold">{{ service.name }}</h3>
        <p v-if="duration(service.durationMinutes)" class="text-xs text-muted-foreground">{{ duration(service.durationMinutes) }}</p>
        <p v-if="service.description" class="mt-1 text-sm text-muted-foreground">{{ service.description }}</p>
      </div>
      <div class="shrink-0 sm:text-right">
        <p v-if="lines(service).length === 0" class="text-sm text-muted-foreground">{{ $t("client.spa.contactPrice") }}</p>
        <dl v-else class="space-y-0.5 text-sm">
          <div v-for="line in lines(service)" :key="line.key" class="flex justify-between gap-4 sm:justify-end">
            <dt v-if="line.label" class="text-muted-foreground">{{ line.label }}</dt>
            <dd class="font-semibold text-primary">{{ formatPrice(line.price) }}</dd>
          </div>
        </dl>
      </div>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { useDurationLabel } from "@/composables/spa/useDurationLabel";
import { formatPrice } from "@/lib/utils";
import type { SpaService, SpaSpecies } from "@/types/spaCatalog";
import { priceLines } from "@/utils/spa/catalog";

const props = defineProps<{ services: SpaService[]; species: SpaSpecies }>();

const duration = useDurationLabel();
const lines = (service: SpaService) => priceLines(service, props.species);
</script>
