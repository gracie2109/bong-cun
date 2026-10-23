<template>
  <WidgetCard
    :title="$t('dashboard.boarding.title')"
    :icon="Home"
    :state="state"
    :to="{ name: 'boardingBoard' }"
    :link-label="$t('boarding.dashboard.open')"
    @retry="refetch()"
  >
    <dl v-if="counts" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="key in KEYS" :key="key">
        <dt class="text-xs text-muted-foreground">{{ $t(`boarding.board.stats.${key}`) }}</dt>
        <dd class="text-xl font-bold" :class="key === 'overdue' && counts.overdue > 0 && 'text-red-600'">{{ counts[key] }}</dd>
      </div>
    </dl>
    <p class="mt-2 text-xs text-muted-foreground">{{ $t("dashboard.boarding.unit") }}</p>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { Home } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useBoardingToday } from "./useBoardingToday";

const KEYS = ["arriving", "departing", "occupied", "overdue"] as const;
const { state, counts, refetch } = useBoardingToday();
</script>
