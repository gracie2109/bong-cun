<template>
  <template v-if="week?.requirePublish">
    <WeekStatusBadge :week="week" />
    <Button v-if="canPublish && week.status === 'draft'" :disabled="publishing" @click="publish">
      <Loader2 v-if="publishing" class="mr-1 size-4 animate-spin" />
      <Send v-else class="mr-1 size-4" />
      {{ $t("attendance.publish.button") }}
    </Button>
    <ConfirmReasonDialog :confirm="confirm" />
  </template>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Loader2, Send } from "lucide-vue-next";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { Button } from "@/components/ui/button";
import type { WeekStatus } from "@bongcun/core/attendance";
import WeekStatusBadge from "./WeekStatusBadge.vue";
import { usePublishWeekAction } from "./usePublishWeek";

const props = defineProps<{ branchId: string | undefined; monday: string; week: WeekStatus | undefined; shifts: number; canPublish: boolean }>();
const { confirm, publish, publishing } = usePublishWeekAction(toRef(props, "branchId"), toRef(props, "monday"), toRef(props, "week"), toRef(props, "shifts"));
</script>
