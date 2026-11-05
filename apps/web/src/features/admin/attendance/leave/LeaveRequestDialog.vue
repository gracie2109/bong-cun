<template>
  <AppDialog
    :open="open"
    :title="forStaff ? $t('attendance.leave.fileFor') : $t('attendance.leave.request')"
    :description="forStaff ? $t('attendance.leave.fileForHint') : undefined"
    :ok-text="forStaff ? $t('petCare.common.save') : $t('attendance.leave.send')"
    :busy="busy"
    form-id="leave-request-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="leave-request-form" class="space-y-4" @submit.prevent="submit">
      <div v-if="forStaff" class="space-y-1">
        <Label for="lr-staff">{{ $t("attendance.leave.staff") }}</Label>
        <select id="lr-staff" v-model="draft.userId" class="h-11 w-full rounded-md border bg-white px-3 text-sm">
          <option value="" disabled>{{ $t("attendance.leave.pickStaff") }}</option>
          <option v-for="person in staff" :key="person.userId" :value="person.userId">{{ person.name }}</option>
        </select>
      </div>

      <div v-if="branches.length > 1 && !forStaff" class="space-y-1">
        <Label>{{ $t("attendance.leave.approver") }}</Label>
        <div class="flex flex-wrap gap-2">
          <ChoiceButton v-for="branch in branches" :key="branch.id" :active="draft.branchId === branch.id" @click="draft.branchId = branch.id">
            {{ branch.name }}
          </ChoiceButton>
        </div>
      </div>

      <div class="space-y-1">
        <Label>{{ $t("attendance.leave.type") }}</Label>
        <div class="flex flex-wrap gap-2">
          <ChoiceButton v-for="type in LEAVE_TYPES" :key="type" :active="draft.leaveType === type" @click="draft.leaveType = type">
            {{ $t(`attendance.leaveType.${type}`) }}
          </ChoiceButton>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div class="space-y-1">
          <Label for="lr-from">{{ $t("attendance.leave.from") }}</Label>
          <Input id="lr-from" v-model="draft.fromDate" type="date" />
        </div>
        <div class="space-y-1">
          <Label for="lr-to">{{ $t("attendance.leave.to") }}</Label>
          <Input id="lr-to" v-model="draft.toDate" type="date" :min="draft.fromDate" />
        </div>
      </div>

      <div v-if="singleDay" class="space-y-1">
        <Label>{{ $t("attendance.leave.part") }}</Label>
        <div class="flex flex-wrap gap-2">
          <ChoiceButton v-for="part in LEAVE_PARTS" :key="part" :active="draft.part === part" @click="draft.part = part">
            {{ $t(`attendance.leavePart.${part}`) }}
          </ChoiceButton>
        </div>
      </div>

      <div class="space-y-1">
        <Label for="lr-reason">{{ $t("attendance.leave.reason") }}</Label>
        <Input id="lr-reason" v-model="draft.reason" maxlength="500" />
      </div>

      <p v-if="error" class="text-sm text-destructive">{{ $t(`attendance.leave.errors.${error}`) }}</p>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ClockBranch, RosterStaff } from "@bongcun/core/attendance";
import ChoiceButton from "./ChoiceButton.vue";
import { LEAVE_PARTS, LEAVE_TYPES } from "./leaveDraft";
import { useLeaveForm } from "./useLeaveForm";

const props = defineProps<{
  open: boolean;
  /** A manager filing for somebody else (approved at once). */
  forStaff?: boolean;
  /** Branches the person works at; the request goes to the one chosen here. */
  branches: Pick<ClockBranch, "id" | "name">[];
  defaultBranchId?: string;
  staff?: RosterStaff[];
}>();
const emit = defineEmits<{ "update:open": [boolean] }>();

const { draft, busy, error, singleDay, submit } = useLeaveForm({
  open: toRef(props, "open"),
  forStaff: toRef(() => !!props.forStaff),
  defaultBranchId: toRef(props, "defaultBranchId"),
  onDone: () => emit("update:open", false),
});
</script>
