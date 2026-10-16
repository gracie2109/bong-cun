<template>
  <p v-if="visits.length === 0" class="rounded-xl border border-dashed bg-white py-10 text-center text-sm text-muted-foreground">
    {{ $t("client.health.noVisits") }}
  </p>
  <ul v-else class="space-y-3">
    <li v-for="visit in visits" :key="visit.id" class="space-y-2 rounded-xl border bg-white p-4 text-sm">
      <div class="flex flex-wrap items-start justify-between gap-2">
        <p class="font-semibold">{{ formatDay(visit.date) }}</p>
        <p class="text-xs text-muted-foreground">{{ visit.branchName }}</p>
      </div>
      <p v-if="visit.reason"><span class="text-muted-foreground">{{ $t("client.health.reason") }}:</span> {{ visit.reason }}</p>
      <p v-if="visit.diagnoses.length"><span class="text-muted-foreground">{{ $t("client.health.diagnosis") }}:</span> {{ visit.diagnoses.join(", ") }}</p>
      <p v-if="visit.ownerInstructions"><span class="text-muted-foreground">{{ $t("client.health.instructions") }}:</span> {{ visit.ownerInstructions }}</p>
      <div v-if="visit.takeHome.length" class="space-y-1">
        <p class="text-muted-foreground">{{ $t("client.health.takeHome") }}</p>
        <ul class="list-disc space-y-0.5 pl-5">
          <li v-for="(drug, index) in visit.takeHome" :key="index">
            <span class="font-medium">{{ drug.name }}</span>
            <span v-if="directions(drug)" class="text-muted-foreground"> · {{ directions(drug) }}</span>
          </li>
        </ul>
      </div>
      <p v-if="visit.recheckOn" class="font-medium text-primary">{{ $t("client.health.recheck", { date: formatDay(visit.recheckOn) }) }}</p>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import type { HealthTakeHome, HealthVisit } from "@bongcun/core/account";
import { formatDay } from "./format";

defineProps<{ visits: HealthVisit[] }>();

const { t } = useI18n();
const directions = (drug: HealthTakeHome) =>
  [drug.dose, drug.frequency, drug.days ? t("client.health.days", { n: drug.days }) : "", drug.route, drug.instructions].filter(Boolean).join(", ");
</script>
