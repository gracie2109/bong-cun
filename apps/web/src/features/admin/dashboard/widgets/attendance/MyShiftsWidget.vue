<template>
  <WidgetCard
    :title="$t('dashboard.myShifts.title')"
    :icon="CalendarClock"
    :state="state"
    :to="{ name: 'attendanceMe' }"
    :link-label="$t('dashboard.myShifts.open')"
    :empty-text="$t('dashboard.myShifts.empty')"
    @retry="refetch()"
  >
    <ul class="space-y-2 text-sm">
      <li v-for="shift in shifts" :key="shift.id" class="flex items-center gap-3">
        <span class="w-24 shrink-0 font-semibold tabular-nums">{{ timeOf(shift.startAt) }}-{{ timeOf(shift.endAt) }}</span>
        <span class="min-w-0 flex-1 truncate">{{ shift.name }} · {{ shift.branchName }}</span>
        <span v-if="shift.hasEntry" class="text-xs font-semibold text-emerald-700">{{ $t("dashboard.myShifts.working") }}</span>
      </li>
    </ul>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { CalendarClock } from "lucide-vue-next";
import { timeOf } from "@/features/admin/attendance";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useMyShifts } from "./useMyShifts";

const { state, shifts, refetch } = useMyShifts();
</script>
