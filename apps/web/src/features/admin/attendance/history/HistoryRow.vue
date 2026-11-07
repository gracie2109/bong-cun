<template>
  <li class="rounded-lg border bg-white px-4 py-3">
    <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
      <span class="rounded-md border px-2 py-0.5 text-xs font-semibold" :class="TONE[actionTone(row.action)]">
        {{ $t(`attendance.history.actions.${row.action}`) }}
      </span>
      <span class="text-sm font-semibold">{{ $t(`attendance.history.entities.${row.entity}`) }}</span>
      <span v-if="subject.name" class="text-sm">{{ subject.name }}<template v-if="subject.date"> · {{ dayMonth(subject.date) }}</template></span>
      <span v-if="row.targetUserName" class="text-sm text-muted-foreground">{{ row.targetUserName }}</span>
      <span v-if="row.wasPublished" class="rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-semibold text-amber-900">
        {{ $t("attendance.history.afterPublish") }}
      </span>
      <span class="ml-auto text-xs text-muted-foreground">{{ when }}</span>
    </div>
    <p class="mt-1 text-xs text-muted-foreground">
      {{ $t("attendance.history.by", { name: row.actorName }) }}
      <template v-if="row.reason"> · {{ $t("attendance.history.reason", { reason: row.reason }) }}</template>
    </p>
    <details class="mt-2">
      <summary class="cursor-pointer text-xs font-medium text-primary">{{ $t("attendance.history.details") }}</summary>
      <HistoryDiff :row="row" class="mt-1" />
    </details>
  </li>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { actionTone } from "@bongcun/core/attendance";
import type { HistoryRow } from "@bongcun/core/attendance";
import { dayMonth } from "@/features/admin/attendance/shared/attendanceFormat";
import HistoryDiff from "./HistoryDiff.vue";
import { historySubject } from "./historyLabels";

const props = defineProps<{ row: HistoryRow }>();

const TONE = {
  good: "border-emerald-200 bg-emerald-50 text-emerald-800",
  bad: "border-red-200 bg-red-50 text-red-800",
  warn: "border-amber-200 bg-amber-50 text-amber-900",
  neutral: "border-slate-200 bg-slate-50 text-slate-600",
};

const subject = computed(() => historySubject(props.row));
const when = computed(() => new Date(props.row.createdAt).toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh", dateStyle: "short", timeStyle: "short" }));
</script>
