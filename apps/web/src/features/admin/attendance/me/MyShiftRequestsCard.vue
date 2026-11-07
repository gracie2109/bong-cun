<template>
  <section class="rounded-xl border bg-white p-4 xl:col-span-2">
    <header class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <div>
        <h2 class="font-semibold">{{ $t("attendance.me.requestsTitle") }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("attendance.me.requestsHint") }}</p>
      </div>
      <Button as-child variant="outline" class="min-h-11">
        <router-link :to="{ name: 'attendanceRegister' }">
          <CalendarPlus class="mr-1 size-4" />
          {{ $t("attendance.register.title") }}
        </router-link>
      </Button>
    </header>

    <p v-if="!requests.length" class="text-sm text-muted-foreground">{{ $t("attendance.me.noRequests") }}</p>
    <ul v-else class="space-y-2">
      <li v-for="request in requests" :key="request.id" class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg border p-3 text-sm">
        <LeaveStatusPill :status="request.status" />
        <span class="font-semibold">{{ request.name }}</span>
        <span class="tabular-nums">
          {{ $t(`attendance.weekday.${isoWeekday(request.workDate)}`) }} {{ dayMonth(request.workDate) }} · {{ timeOf(request.startAt) }}–{{ timeOf(request.endAt) }}
        </span>
        <span class="text-muted-foreground">{{ request.branchName }}</span>
        <span v-if="request.expired" class="text-xs text-muted-foreground">{{ $t("attendance.requests.flags.expired") }}</span>
        <span v-if="request.status === 'approved' && !request.assignmentId" class="text-xs text-muted-foreground">{{ $t("attendance.requests.flags.removed") }}</span>
        <span v-if="request.decisionNote" class="w-full text-xs text-muted-foreground">{{ request.decisionNote }}</span>
        <Button v-if="request.status === 'pending' && !request.expired" type="button" size="sm" variant="ghost" class="ml-auto min-h-9" :disabled="cancelling" @click="cancelRequest(request.id)">
          {{ $t("attendance.register.cancel") }}
        </Button>
      </li>
    </ul>
  </section>
  <ConfirmReasonDialog :confirm="confirm" />
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { CalendarPlus } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Button } from "@/components/ui/button";
import { useCancelShiftRequest, useMyShiftRequests } from "@/features/admin/attendance/queries";
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import { todayInVietnam } from "@/lib/businessDate";
import { addDays, isoWeekday } from "@bongcun/core/attendance";
import LeaveStatusPill from "../leave/LeaveStatusPill.vue";

// Requests from today to four weeks ahead, the span the registration window can reach.
const from = todayInVietnam();
const query = useMyShiftRequests(from, addDays(from, 28));
const requests = computed(() => (query.data.value ?? []).filter((request) => request.status !== "cancelled"));
const cancel = useCancelShiftRequest();
const cancelling = cancel.isPending;
const { t } = useI18n();
const confirm = useConfirmAction();
const cancelRequest = async (id: string) => {
  const answer = await confirm.ask({
    title: t("attendance.confirm.cancelRequest.title"),
    message: t("attendance.confirm.cancelRequest.message"),
    danger: true,
  });
  if (answer.ok) cancel.mutate(id);
};
</script>
