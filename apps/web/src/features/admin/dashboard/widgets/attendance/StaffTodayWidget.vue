<template>
  <WidgetCard
    :title="$t('dashboard.staff.title')"
    :icon="UsersRound"
    :state="state"
    :to="{ name: 'attendanceToday' }"
    :link-label="$t('dashboard.staff.open')"
    @retry="refetch()"
  >
    <dl v-if="stats" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="item in stats" :key="item.key">
        <dt class="text-xs text-muted-foreground">{{ $t(`dashboard.staff.${item.key}`) }}</dt>
        <dd class="text-xl font-bold" :class="item.key === 'notIn' && item.value > 0 && 'text-red-600'">{{ item.value }}</dd>
      </div>
    </dl>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { UsersRound } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useStaffToday } from "./useStaffToday";

const { state, stats, refetch } = useStaffToday();
</script>
