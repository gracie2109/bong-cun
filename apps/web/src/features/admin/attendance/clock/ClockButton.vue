<template>
  <template v-if="available">
    <Button
      type="button"
      size="sm"
      class="min-h-9 gap-1.5 font-semibold"
      :class="openEntry ? 'bg-emerald-600 text-white hover:bg-emerald-700' : ''"
      :variant="openEntry ? 'default' : 'outline'"
      :disabled="busy"
      @click="press"
    >
      <Clock class="size-4" />
      <span v-if="openEntry" class="hidden sm:inline">{{ $t("attendance.clock.working", { time: formatMinutes(elapsed) }) }}</span>
      <span v-else class="hidden sm:inline">{{ $t("attendance.clock.in") }}</span>
    </Button>

    <ClockDialog
      v-model:open="dialogOpen"
      :open-entry="openEntry"
      :branches="branches"
      :shifts="data?.shifts ?? []"
      :elapsed="elapsed"
      :busy="busy"
      :unscheduled-for="unscheduledFor"
      @start="onStart"
      @stop="onStop"
    />
  </template>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { Clock } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { formatMinutes } from "@/features/admin/attendance/shared/attendanceFormat";
import ClockDialog from "./ClockDialog.vue";
import { useClock } from "./useClock";

const { data, openEntry, branches, elapsed, available, busy, unscheduledFor, start, stop } = useClock();
const dialogOpen = ref(false);

// Clocking in at the only branch needs no dialog, unless the answer to "no shift now?" is pending.
const press = async () => {
  if (!openEntry.value && branches.value.length === 1) {
    const done = await start(branches.value[0].id);
    if (!done && unscheduledFor.value) dialogOpen.value = true;
    return;
  }
  dialogOpen.value = true;
};

const onStart = async (branchId: string, note: string | undefined, unscheduledOk: boolean) => {
  if (await start(branchId, note, unscheduledOk)) dialogOpen.value = false;
};
const onStop = async (note: string | undefined) => {
  if (await stop(note)) dialogOpen.value = false;
};
</script>
