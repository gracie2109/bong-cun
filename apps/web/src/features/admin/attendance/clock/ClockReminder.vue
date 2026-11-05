<template>
  <div v-if="show" class="flex items-center justify-between gap-3 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
    <p>{{ $t("attendance.clock.reminder") }}</p>
    <Button type="button" size="sm" variant="outline" class="min-h-9 shrink-0 bg-white" :disabled="busy" @click="clockInNow">
      {{ $t("attendance.clock.reminderAction") }}
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import { useClockIn, useClockStatus } from "@/features/admin/attendance/queries";

const props = defineProps<{ branchId: string }>();

// A hint for whoever opens a till: not clocked in at this branch yet. It never blocks the shift.
const status = useClockStatus();
const clockIn = useClockIn();
const busy = computed(() => clockIn.isPending.value);
const show = computed(() => {
  const data = status.data.value;
  if (!data || data.openEntry) return false;
  return data.branches.some((branch) => branch.id === props.branchId);
});

const clockInNow = async () => {
  try {
    await clockIn.mutateAsync({ branchId: props.branchId, unscheduledOk: true });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
