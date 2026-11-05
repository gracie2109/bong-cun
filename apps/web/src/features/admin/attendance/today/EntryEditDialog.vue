<template>
  <AppDialog
    :open="open"
    :title="isNew ? $t('attendance.today.addEntry') : $t('attendance.today.editEntry')"
    :description="row ? `${row.userName} · ${dayMonth(row.workDate)}${row.shiftName ? ` · ${row.shiftName}` : ''}` : undefined"
    :ok-text="$t('petCare.common.save')"
    :busy="busy"
    form-id="entry-edit-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="entry-edit-form" class="space-y-4" @submit.prevent="emit('submit')">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div class="space-y-1">
          <Label for="ee-in">{{ $t("attendance.today.checkIn") }}</Label>
          <Input id="ee-in" v-model="draft.checkIn" type="datetime-local" />
        </div>
        <div class="space-y-1">
          <Label for="ee-out">{{ $t("attendance.today.checkOut") }}</Label>
          <Input id="ee-out" v-model="draft.checkOut" type="datetime-local" />
        </div>
      </div>

      <div class="space-y-1">
        <Label for="ee-reason">{{ $t("attendance.today.reason") }}</Label>
        <Input id="ee-reason" v-model="draft.reason" maxlength="300" :placeholder="$t('attendance.today.reasonHint')" />
      </div>

      <p v-if="error" class="text-sm text-destructive">{{ $t(`attendance.today.errors.${error}`) }}</p>

      <Button v-if="!isNew && canDelete" type="button" variant="outline" class="text-destructive" :disabled="busy" @click="emit('remove')">
        <Trash2 class="mr-1 size-4" />
        {{ $t("attendance.today.deleteEntry") }}
      </Button>

      <EntryHistory v-if="!isNew" :changes="history" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Trash2 } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useEntryHistory } from "@/features/admin/attendance/queries";
import { dayMonth } from "@/features/admin/attendance/shared/attendanceFormat";
import type { AttendanceRow } from "@bongcun/core/attendance";
import EntryHistory from "./EntryHistory.vue";
import type { DraftError, EntryDraft } from "./entryDraft";

const props = defineProps<{
  open: boolean;
  row: AttendanceRow | null;
  isNew: boolean;
  busy: boolean;
  error: DraftError | null;
  canDelete: boolean;
}>();
const draft = defineModel<EntryDraft>("draft", { required: true });
const emit = defineEmits<{ "update:open": [boolean]; submit: []; remove: [] }>();

const historyQuery = useEntryHistory(computed(() => (props.open && !props.isNew ? props.row?.entryId : null)));
const history = computed(() => historyQuery.data.value ?? []);
</script>
