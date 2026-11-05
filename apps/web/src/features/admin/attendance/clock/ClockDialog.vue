<template>
  <AppDialog
    :open="open"
    :title="openEntry ? $t('attendance.clock.outTitle') : $t('attendance.clock.inTitle')"
    :description="openEntry ? `${openEntry.branchName} · ${openEntry.shiftName ?? $t('attendance.clock.noShift')}` : undefined"
    :ok-text="okText"
    :busy="busy"
    form-id="clock-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="clock-form" class="space-y-4" @submit.prevent="submit">
      <template v-if="openEntry">
        <p class="text-sm text-muted-foreground">
          {{ $t("attendance.clock.since", { time: timeOf(openEntry.checkInAt), worked: formatMinutes(elapsed) }) }}
        </p>
      </template>

      <template v-else>
        <div v-if="branches.length > 1" class="space-y-1">
          <Label>{{ $t("attendance.clock.branch") }}</Label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="branch in branches"
              :key="branch.id"
              type="button"
              class="min-h-11 rounded-lg border px-3 text-sm font-semibold"
              :class="branchId === branch.id ? 'border-primary bg-primary/10 text-primary ring-2 ring-primary' : 'bg-white text-muted-foreground hover:bg-muted'"
              @click="branchId = branch.id"
            >
              {{ branch.name }}
            </button>
          </div>
        </div>

        <ul v-if="shiftsHere.length" class="space-y-1 rounded-lg border bg-muted/30 p-3 text-sm">
          <li v-for="shift in shiftsHere" :key="shift.id">{{ shift.name }} · {{ timeOf(shift.startAt) }}–{{ timeOf(shift.endAt) }}</li>
        </ul>
        <p v-else class="text-sm text-muted-foreground">{{ $t("attendance.clock.noShiftToday") }}</p>

        <p v-if="unscheduledFor" class="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
          {{ $t("attendance.clock.unscheduledAsk") }}
        </p>
      </template>

      <div class="space-y-1">
        <Label for="clock-note">{{ $t("attendance.clock.note") }}</Label>
        <Input id="clock-note" v-model="note" maxlength="300" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { formatMinutes, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { ClockBranch, ClockShift, OpenEntry } from "@bongcun/core/attendance";

const props = defineProps<{
  open: boolean;
  openEntry: OpenEntry | null;
  branches: ClockBranch[];
  shifts: ClockShift[];
  elapsed: number;
  busy: boolean;
  /** The branch that asked "no shift now, clock in anyway?". */
  unscheduledFor: string | null;
}>();
const emit = defineEmits<{
  "update:open": [boolean];
  start: [branchId: string, note: string | undefined, unscheduledOk: boolean];
  stop: [note: string | undefined];
}>();

const { t } = useI18n();
const branchId = ref<string>("");
const note = ref("");

watch(
  () => [props.open, props.branches] as const,
  () => {
    if (props.open && !props.branches.some((branch) => branch.id === branchId.value)) branchId.value = props.branches[0]?.id ?? "";
    if (!props.open) note.value = "";
  },
  { immediate: true }
);

const shiftsHere = computed(() => props.shifts.filter((shift) => shift.branchId === branchId.value));
const okText = computed(() => {
  if (props.openEntry) return t("attendance.clock.out");
  return props.unscheduledFor ? t("attendance.clock.inAnyway") : t("attendance.clock.in");
});

const submit = () => {
  const trimmed = note.value.trim() || undefined;
  if (props.openEntry) emit("stop", trimmed);
  else if (branchId.value) emit("start", branchId.value, trimmed, props.unscheduledFor === branchId.value);
};
</script>
