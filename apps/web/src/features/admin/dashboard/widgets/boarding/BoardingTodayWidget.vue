<template>
  <WidgetCard
    :title="$t('dashboard.boarding.title')"
    :icon="Home"
    :state="state"
    :to="{ name: 'boardingBoard' }"
    :link-label="$t('boarding.dashboard.open')"
    @retry="refetch()"
  >
    <div class="mb-3 inline-flex rounded-md border p-0.5 text-xs" role="group" :aria-label="$t('dashboard.boarding.unitLabel')">
      <button
        v-for="option in UNITS"
        :key="option"
        type="button"
        class="rounded px-2.5 py-1 font-medium transition-colors"
        :class="unit === option ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground'"
        :aria-pressed="unit === option"
        @click="unit = option"
      >
        {{ $t(`dashboard.boarding.unit_${option}`) }}
      </button>
    </div>
    <dl v-if="counts" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="key in KEYS" :key="key">
        <dt class="text-xs text-muted-foreground">{{ $t(`boarding.board.stats.${key}`) }}</dt>
        <dd class="text-xl font-bold" :class="key === 'overdue' && counts.overdue > 0 && 'text-red-600'">{{ counts[key] }}</dd>
      </div>
    </dl>
    <p class="mt-2 text-xs text-muted-foreground">{{ $t(`dashboard.boarding.note_${unit}`) }}</p>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { Home } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useBoardingToday, type BoardingUnit } from "./useBoardingToday";

const KEYS = ["arriving", "departing", "occupied", "overdue"] as const;
const UNITS: BoardingUnit[] = ["kennels", "pets"];
const { state, counts, unit, refetch } = useBoardingToday();
</script>
