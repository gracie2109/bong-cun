<template>
  <AppDialog
    :open="open"
    :title="template ? $t('attendance.templates.edit') : $t('attendance.templates.add')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!!error"
    :busy="mutation.isPending.value"
    form-id="shift-template-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="shift-template-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1">
        <Label for="tpl-name">{{ $t("attendance.templates.name") }}</Label>
        <Input id="tpl-name" v-model="draft.name" maxlength="40" :placeholder="$t('attendance.templates.namePlaceholder')" />
      </div>
      <div class="grid grid-cols-2 gap-3">
        <div class="space-y-1">
          <Label for="tpl-start">{{ $t("attendance.templates.start") }}</Label>
          <Input id="tpl-start" v-model="draft.startTime" type="time" step="900" />
        </div>
        <div class="space-y-1">
          <Label for="tpl-end">{{ $t("attendance.templates.end") }}</Label>
          <Input id="tpl-end" v-model="draft.endTime" type="time" step="900" />
        </div>
      </div>
      <p class="text-xs text-muted-foreground">
        {{ overnight ? $t("attendance.templates.overnightHint") : $t("attendance.templates.sameDayHint") }}
      </p>
      <div class="space-y-1">
        <Label for="tpl-break">{{ $t("attendance.templates.breakMinutes") }}</Label>
        <Input id="tpl-break" v-model="draft.breakMinutes" type="number" min="0" step="5" inputmode="numeric" />
      </div>
      <div class="space-y-1">
        <Label>{{ $t("attendance.templates.color") }}</Label>
        <ColorPicker v-model="draft.color" />
      </div>
      <p v-if="draft.name && error" class="text-sm text-destructive">{{ $t(`attendance.templates.errors.${error}`) }}</p>
    </form>
  </AppDialog>
  <ConfirmReasonDialog :confirm="confirm" />
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useSaveShiftTemplate } from "@/features/admin/attendance/queries";
import { isOvernight } from "@bongcun/core/attendance";
import type { ShiftTemplate } from "@bongcun/core/attendance";
import ColorPicker from "./ColorPicker.vue";
import { draftFromTemplate, emptyTemplateDraft, templateDraftError, templateInputFromDraft } from "./templateDraft";

const props = defineProps<{ open: boolean; branchId: string | undefined; template: ShiftTemplate | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { t } = useI18n();
const confirm = useConfirmAction();
const mutation = useSaveShiftTemplate();
const draft = ref(emptyTemplateDraft());
const error = computed(() => templateDraftError(draft.value));
const overnight = computed(() => draft.value.startTime !== draft.value.endTime && isOvernight(draft.value.startTime, draft.value.endTime));

// Every opening starts from the row being edited, or from an empty form.
watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) draft.value = props.template ? draftFromTemplate(props.template) : emptyTemplateDraft();
  },
  { immediate: true }
);

const submit = async () => {
  if (error.value || !props.branchId) return;
  if (props.template) {
    const answer = await confirm.ask({
      title: t("attendance.confirm.updateTemplate.title"),
      message: t("attendance.confirm.updateTemplate.message", { name: props.template.name }),
    });
    if (!answer.ok) return;
  }
  try {
    await mutation.mutateAsync({ branchId: props.branchId, input: templateInputFromDraft(draft.value, props.template?.id) });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
