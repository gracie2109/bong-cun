<template>
  <AppDialog
    :open="open"
    :title="$t('attendance.leave.decideTitle')"
    :description="request ? `${request.userName} · ${dayMonth(request.fromDate)}${request.toDate !== request.fromDate ? `–${dayMonth(request.toDate)}` : ''} · ${request.days} ${$t('attendance.leave.days')}` : undefined"
    :hide-footer="true"
    @update:open="emit('update:open', $event)"
  >
    <div v-if="request" class="space-y-4">
      <p class="rounded-lg border bg-muted/30 px-3 py-2 text-sm">{{ request.reason }}</p>
      <LeaveBalanceChip :user-id="request.userId" :year="Number(request.fromDate.slice(0, 4))" />

      <div class="space-y-1">
        <Label>{{ $t("attendance.leave.type") }}</Label>
        <div class="flex flex-wrap gap-2">
          <ChoiceButton v-for="type in LEAVE_TYPES" :key="type" :active="leaveType === type" @click="leaveType = type">
            {{ $t(`attendance.leaveType.${type}`) }}
          </ChoiceButton>
        </div>
        <p class="text-xs text-muted-foreground">{{ $t("attendance.leave.changeTypeHint") }}</p>
      </div>

      <div class="space-y-1">
        <Label for="ld-note">{{ $t("attendance.leave.note") }}</Label>
        <Input id="ld-note" v-model="note" maxlength="500" />
      </div>

      <div class="flex flex-wrap justify-end gap-2">
        <Button type="button" variant="outline" class="min-h-11 text-destructive" :disabled="busy" @click="decide(false)">{{ $t("attendance.leave.reject") }}</Button>
        <Button type="button" class="min-h-11" :disabled="busy" @click="decide(true)">{{ $t("attendance.leave.approve") }}</Button>
      </div>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useDecideLeave } from "@/features/admin/attendance/queries";
import { dayMonth } from "@/features/admin/attendance/shared/attendanceFormat";
import type { LeaveRequest, LeaveType } from "@bongcun/core/attendance";
import ChoiceButton from "./ChoiceButton.vue";
import LeaveBalanceChip from "./LeaveBalanceChip.vue";
import { LEAVE_TYPES } from "./leaveDraft";

const props = defineProps<{ open: boolean; request: LeaveRequest | null }>();
const emit = defineEmits<{ "update:open": [boolean] }>();

const mutation = useDecideLeave();
const busy = mutation.isPending;
const leaveType = ref<LeaveType>("annual");
const note = ref("");

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen || !props.request) return;
    leaveType.value = props.request.leaveType;
    note.value = "";
  }
);

const decide = async (approve: boolean) => {
  if (!props.request) return;
  try {
    await mutation.mutateAsync({ id: props.request.id, approve, note: note.value.trim() || undefined, leaveType: leaveType.value });
    emit("update:open", false);
  } catch {
    // the mutation already showed why
  }
};
</script>
