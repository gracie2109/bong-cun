<template>
  <AppDialog
    :open="open"
    :title="$t('attendance.roster.copyTitle')"
    :description="$t('attendance.roster.copyHint', { from: fromMonday, to: toMonday })"
    :ok-text="$t('attendance.roster.copyOk')"
    :busy="mutation.isPending.value"
    form-id="copy-week-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="copy-week-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1">
        <Label>{{ $t("attendance.roster.copyFrom") }}</Label>
        <WeekRangePicker
          :monday="fromMonday"
          :label="fromLabel"
          @previous="fromMonday = addDays(fromMonday, -7)"
          @next="fromMonday = addDays(fromMonday, 7)"
          @select="(value) => (fromMonday = value)"
        />
        <p v-if="fromMonday === toMonday" class="text-xs text-destructive">{{ $t("attendance.roster.errors.sameWeek") }}</p>
      </div>
      <label class="flex items-start justify-between gap-3 rounded-lg border p-3">
        <span>
          <span class="text-sm font-semibold">{{ $t("attendance.roster.overwrite") }}</span>
          <span class="block text-xs text-muted-foreground">{{ $t("attendance.roster.overwriteHint") }}</span>
        </span>
        <Switch v-model:checked="overwrite" />
      </label>
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
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useCopyWeek } from "@/features/admin/attendance/queries";
import { addDays } from "@bongcun/core/attendance";
import WeekRangePicker from "../shared/WeekRangePicker.vue";

const props = defineProps<{ open: boolean; branchId: string | undefined; toMonday: string; published?: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { t } = useI18n();
const confirm = useConfirmAction();
const mutation = useCopyWeek();
const fromMonday = ref("");
const overwrite = ref(false);
const fromLabel = computed(() => {
  const sunday = addDays(fromMonday.value, 6);
  return `${fromMonday.value.slice(8)}/${fromMonday.value.slice(5, 7)} – ${sunday.slice(8)}/${sunday.slice(5, 7)}/${sunday.slice(0, 4)}`;
});

// The week before the one shown is the usual source.
watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    fromMonday.value = addDays(props.toMonday, -7);
    overwrite.value = false;
  },
  { immediate: true }
);

const submit = async () => {
  if (!props.branchId || !fromMonday.value || fromMonday.value === props.toMonday) return;
  // Overwriting deletes shifts that are already there, so it asks first.
  let reason: string | null = null;
  if (overwrite.value || props.published) {
    const answer = await confirm.ask({
      title: t("attendance.confirm.overwriteWeek.title"),
      message:
        t("attendance.confirm.overwriteWeek.message", { from: fromMonday.value, to: props.toMonday }) +
        (props.published ? ` ${t("attendance.publish.editNotice")}` : ""),
      okText: t("attendance.roster.copyOk"),
      danger: true,
      reason: { label: t("attendance.confirm.reasonLabel"), placeholder: t("attendance.confirm.reasonHint") },
    });
    if (!answer.ok) return;
    reason = answer.reason;
  }
  try {
    await mutation.mutateAsync({ branchId: props.branchId, fromMonday: fromMonday.value, toMonday: props.toMonday, overwrite: overwrite.value, reason });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
