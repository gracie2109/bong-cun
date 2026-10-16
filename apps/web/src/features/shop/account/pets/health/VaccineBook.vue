<template>
  <p v-if="vaccines.length === 0" class="rounded-xl border border-dashed bg-white py-10 text-center text-sm text-muted-foreground">
    {{ $t("client.health.noVaccines") }}
  </p>
  <ul v-else class="space-y-3">
    <li v-for="vaccine in vaccines" :key="vaccine.vaccineTypeId" class="space-y-2 rounded-xl border bg-white p-4">
      <div class="flex flex-wrap items-start justify-between gap-2">
        <div>
          <p class="font-semibold">{{ vaccine.name }}</p>
          <p class="text-xs text-muted-foreground">{{ $t("client.health.lastGiven", { date: formatDay(vaccine.lastGivenOn) }) }}</p>
        </div>
        <span class="rounded-full px-2.5 py-0.5 text-xs font-semibold" :class="STATE_TONE[vaccine.state]">
          <template v-if="vaccine.nextDueOn">{{ $t(`client.health.state.${vaccine.state}`, { date: formatDay(vaccine.nextDueOn) }) }}</template>
          <template v-else>{{ $t("client.health.state.none") }}</template>
        </span>
      </div>
      <ul class="divide-y rounded-lg border text-sm">
        <li v-for="(dose, index) in vaccine.doses" :key="index" class="flex items-center justify-between gap-2 px-3 py-1.5">
          <span>{{ dose.doseNo ? $t("client.health.dose", { n: dose.doseNo }) : $t("client.health.doseOne") }} · {{ formatDay(dose.givenOn) }}</span>
          <span class="text-xs text-muted-foreground">{{ dose.isExternal ? dose.externalPlace || $t("client.health.external") : $t("client.health.atShop") }}</span>
        </li>
      </ul>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import type { HealthVaccine } from "@bongcun/core/account";
import { formatDay } from "./format";

defineProps<{ vaccines: HealthVaccine[] }>();

const STATE_TONE: Record<HealthVaccine["state"], string> = {
  ok: "bg-emerald-100 text-emerald-800",
  due_soon: "bg-amber-100 text-amber-800",
  overdue: "bg-red-100 text-red-800",
};
</script>
