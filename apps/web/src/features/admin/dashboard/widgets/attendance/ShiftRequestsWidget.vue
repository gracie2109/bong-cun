<template>
  <WidgetCard
    :title="$t('dashboard.shiftRequests.title')"
    :icon="ClipboardCheck"
    :state="state"
    :to="{ name: 'attendanceRequests' }"
    :link-label="$t('dashboard.shiftRequests.open')"
    :empty-text="$t('dashboard.shiftRequests.empty')"
    @retry="refetch()"
  >
    <p class="text-3xl font-bold" :class="count > 0 && 'text-amber-600'">{{ count }}</p>
    <p class="text-sm text-muted-foreground">{{ $t("dashboard.shiftRequests.hint") }}</p>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { ClipboardCheck } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useShiftRequestsWidget } from "./useShiftRequestsWidget";

const { state, count, refetch } = useShiftRequestsWidget();
</script>
