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

      <Button v-if="assignment" type="button" variant="outline" class="mr-2" @click="historyOpen = true">
        <History class="mr-1 size-4" />
        {{ $t("attendance.history.history") }}
      </Button>
      <Button v-if="assignment && canDelete" type="button" variant="outline" class="text-destructive" :disabled="busy || locked" @click="remove">
        <Trash2 class="mr-1 size-4" />
        {{ $t("attendance.roster.removeShift") }}
      </Button>
    </form>
  </AppDialog>
  <ConfirmReasonDialog :confirm="confirm" />
  <CellHistoryDialog v-model:open="historyOpen" entity="assignment" :entity-id="assignment?.id" :description="`${staff?.name ?? ''} · ${date}`" />
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { History, Trash2 } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAssignShift, useRemoveShift, useUpdateShift } from "@/features/admin/attendance/queries";
import { SHIFT_COLOR_CLASS } from "@/features/admin/attendance/shared/shiftColors";
import type { RosterAssignment, RosterAvailability, RosterStaff, ShiftTemplate } from "@bongcun/core/attendance";
import CellHistoryDialog from "../history/CellHistoryDialog.vue";
import AvailabilityHint from "./AvailabilityHint.vue";
import { applyTemplate, assignDraftError, assignInputFromDraft, draftFromAssignment, emptyAssignDraft, updateInputFromDraft } from "./assignDraft";

const props = defineProps<{
  open: boolean;
  branchId: string | undefined;
  staff: RosterStaff | null;
  date: string;
  assignment: RosterAssignment | null;
  /** A new shift starts from this template (when added from a shift row). */
  presetTemplateId?: string | null;
  templates: ShiftTemplate[];
  canDelete: boolean;
  availability: RosterAvailability[];
  /** The week is already published: staff hear about every change. */
  published?: boolean;
}>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { t } = useI18n();
const historyOpen = ref(false);
const confirm = useConfirmAction();
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
    draft.value = props.assignment
      ? draftFromAssignment(props.assignment)
      : emptyAssignDraft(props.templates.find((item) => item.id === props.presetTemplateId) ?? props.templates[0]);
  },
  { immediate: true }
);

const publishedNotice = computed(() => (props.published ? ` ${t("attendance.publish.editNotice")}` : ""));

const submit = async () => {
  if (error.value || locked.value || !props.branchId || !props.staff) return;
  try {
    if (props.assignment) {
      const answer = await confirm.ask({
        title: t("attendance.confirm.updateShift.title"),
        message: t("attendance.confirm.updateShift.message", { name: props.staff.name, date: props.date }) + publishedNotice.value,
        reason: { label: t("attendance.confirm.reasonLabel"), placeholder: t("attendance.confirm.reasonHint") },
      });
      if (!answer.ok) return;
      await update.mutateAsync({ ...updateInputFromDraft(draft.value, props.assignment.id), reason: answer.reason });
    }
    else {
      let reason: string | null = null;
      if (props.published) {
        const answer = await confirm.ask({
          title: t("attendance.publish.confirmAdd.title"),
          message: t("attendance.publish.confirmAdd.message", { name: props.staff.name, date: props.date }),
          reason: { label: t("attendance.confirm.reasonLabel"), placeholder: t("attendance.confirm.reasonHint") },
        });
        if (!answer.ok) return;
        reason = answer.reason;
      }
      await assign.mutateAsync({ ...assignInputFromDraft(draft.value, { branchId: props.branchId, userId: props.staff.userId, workDate: props.date }), reason });
    }
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};

const remove = async () => {
  if (!props.assignment) return;
  const answer = await confirm.ask({
    title: t("attendance.confirm.removeShift.title"),
    message: t("attendance.confirm.removeShift.message", { name: props.staff?.name ?? "", date: props.date }) + publishedNotice.value,
    okText: t("attendance.roster.removeShift"),
    danger: true,
    reason: { label: t("attendance.confirm.reasonLabel"), placeholder: t("attendance.confirm.reasonHint") },
  });
  if (!answer.ok) return;
  try {
    await removal.mutateAsync({ id: props.assignment.id, reason: answer.reason });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
