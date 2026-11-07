<template>
  <AppDialog
    :open="open"
    :title="assignment ? $t('attendance.roster.editShift') : $t('attendance.roster.addShift')"
    :description="`${staff?.name ?? ''} · ${date}`"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!!error || locked"
    :busy="busy"
    form-id="assign-shift-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="assign-shift-form" class="space-y-4" @submit.prevent="submit">
      <AvailabilityHint :availability="availability" :user-id="staff?.userId" :date="date" :name="staff?.name ?? ''" />
      <p v-if="locked" class="rounded-lg border border-dashed px-3 py-2 text-sm text-muted-foreground">{{ $t("attendance.roster.hasEntry") }}</p>

      <div class="space-y-1">
        <Label>{{ $t("attendance.roster.template") }}</Label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="item in templates"
            :key="item.id"
            type="button"
            class="min-h-11 rounded-lg border px-3 text-sm font-semibold"
            :class="draft.templateId === item.id ? `${SHIFT_COLOR_CLASS[item.color].chip} ring-2 ring-primary` : 'bg-white text-muted-foreground hover:bg-muted'"
            :disabled="locked"
            @click="draft = applyTemplate(draft, item)"
          >
            {{ item.name }} <span class="ml-1 text-xs font-normal">{{ item.startTime }}–{{ item.endTime }}</span>
          </button>
          <button
            type="button"
            class="min-h-11 rounded-lg border px-3 text-sm font-semibold"
            :class="draft.templateId === null ? 'border-primary bg-primary/10 text-primary ring-2 ring-primary' : 'bg-white text-muted-foreground hover:bg-muted'"
            :disabled="locked"
            @click="draft = applyTemplate(draft, null)"
          >
            {{ $t("attendance.roster.custom") }}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <div class="space-y-1">
          <Label for="as-start">{{ $t("attendance.templates.start") }}</Label>
          <Input id="as-start" v-model="draft.startTime" type="time" step="900" :disabled="locked || draft.templateId !== null" />
        </div>
        <div class="space-y-1">
          <Label for="as-end">{{ $t("attendance.templates.end") }}</Label>
          <Input id="as-end" v-model="draft.endTime" type="time" step="900" :disabled="locked || draft.templateId !== null" />
        </div>
        <div class="space-y-1">
          <Label for="as-break">{{ $t("attendance.roster.break") }}</Label>
          <Input id="as-break" v-model="draft.breakMinutes" type="number" min="0" step="5" inputmode="numeric" :disabled="locked" />
        </div>
      </div>

      <div class="space-y-1">
        <Label for="as-note">{{ $t("attendance.roster.note") }}</Label>
        <Input id="as-note" v-model="draft.note" maxlength="300" />
      </div>

      <p v-if="error" class="text-sm text-destructive">{{ $t(`attendance.roster.errors.${error}`) }}</p>

      <Button v-if="assignment && canDelete" type="button" variant="outline" class="text-destructive" :disabled="busy || locked" @click="remove">
        <Trash2 class="mr-1 size-4" />
        {{ $t("attendance.roster.removeShift") }}
      </Button>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Trash2 } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAssignShift, useRemoveShift, useUpdateShift } from "@/features/admin/attendance/queries";
import { SHIFT_COLOR_CLASS } from "@/features/admin/attendance/shared/shiftColors";
import type { RosterAssignment, RosterAvailability, RosterStaff, ShiftTemplate } from "@bongcun/core/attendance";
import AvailabilityHint from "./AvailabilityHint.vue";
import { applyTemplate, assignDraftError, assignInputFromDraft, draftFromAssignment, emptyAssignDraft, updateInputFromDraft } from "./assignDraft";

const props = defineProps<{
  open: boolean;
  branchId: string | undefined;
  staff: RosterStaff | null;
  date: string;
  assignment: RosterAssignment | null;
  templates: ShiftTemplate[];
  canDelete: boolean;
  availability: RosterAvailability[];
}>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const assign = useAssignShift();
const update = useUpdateShift();
const removal = useRemoveShift();
const busy = computed(() => assign.isPending.value || update.isPending.value || removal.isPending.value);

const draft = ref(emptyAssignDraft());
const error = computed(() => assignDraftError(draft.value));
// A shift somebody already clocked in on only lets the note change (the database enforces it too).
const locked = computed(() => !!props.assignment?.hasEntry);

// Every opening starts from the shift being edited, or from the first template.
watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    draft.value = props.assignment ? draftFromAssignment(props.assignment) : emptyAssignDraft(props.templates[0]);
  },
  { immediate: true }
);

const submit = async () => {
  if (error.value || locked.value || !props.branchId || !props.staff) return;
  try {
    if (props.assignment) await update.mutateAsync(updateInputFromDraft(draft.value, props.assignment.id));
    else await assign.mutateAsync(assignInputFromDraft(draft.value, { branchId: props.branchId, userId: props.staff.userId, workDate: props.date }));
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};

const remove = async () => {
  if (!props.assignment) return;
  try {
    await removal.mutateAsync(props.assignment.id);
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
