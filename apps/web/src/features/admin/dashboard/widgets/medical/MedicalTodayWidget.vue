<template>
  <WidgetCard
    :title="$t('medical.dashboard.title')"
    :icon="Stethoscope"
    :state="state"
    :to="{ name: 'medicalQueue' }"
    :link-label="$t('medical.dashboard.open')"
    @retry="refetch()"
  >
    <dl v-if="stats" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="item in stats" :key="item.key">
        <dt class="text-xs text-muted-foreground">{{ $t(`medical.dashboard.${item.key}`) }}</dt>
        <dd class="text-xl font-bold" :class="item.key === 'overdue' && item.value > 0 && 'text-red-600'">{{ item.value }}</dd>
      </div>
    </dl>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { Stethoscope } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useMedicalToday } from "./useMedicalToday";

const { state, stats, refetch } = useMedicalToday();
</script>
