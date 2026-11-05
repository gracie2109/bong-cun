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
        <Label for="cw-from">{{ $t("attendance.roster.copyFrom") }}</Label>
        <Input id="cw-from" v-model="fromMonday" type="date" />
        <p v-if="!fromIsMonday" class="text-xs text-destructive">{{ $t("attendance.roster.errors.monday") }}</p>
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
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useCopyWeek } from "@/features/admin/attendance/queries";
import { addDays, isoWeekday } from "@bongcun/core/attendance";

const props = defineProps<{ open: boolean; branchId: string | undefined; toMonday: string }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const mutation = useCopyWeek();
const fromMonday = ref("");
const overwrite = ref(false);
const fromIsMonday = computed(() => !fromMonday.value || isoWeekday(fromMonday.value) === 1);

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
  if (!props.branchId || !fromMonday.value || !fromIsMonday.value || fromMonday.value === props.toMonday) return;
  try {
    await mutation.mutateAsync({ branchId: props.branchId, fromMonday: fromMonday.value, toMonday: props.toMonday, overwrite: overwrite.value });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
