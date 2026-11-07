<template>
  <AppDialog
    :open="open"
    :title="title ?? $t('attendance.availability.edit')"
    :description="$t('attendance.availability.hint')"
    :ok-text="$t('petCare.common.save')"
    :busy="busy"
    form-id="availability-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="availability-form" class="space-y-4" @submit.prevent="submit">
      <p v-if="loading" class="text-sm text-muted-foreground">…</p>
      <section v-for="day in 7" :key="day" class="space-y-2">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-semibold">{{ $t(`attendance.weekday.${day}`) }}</h3>
          <Button type="button" size="sm" variant="outline" class="min-h-9" @click="add(day)">
            <Plus class="mr-1 size-4" />{{ $t("attendance.availability.add") }}
          </Button>
        </div>
        <ul class="space-y-2">
          <AvailabilityRowEditor v-for="row in rowsOf(day)" :key="row.key" :row="row" @remove="remove(row.key)" />
        </ul>
      </section>
      <p v-if="issue" class="text-sm text-destructive">{{ $t(`attendance.availability.errors.${issue}`) }}</p>
    </form>
  </AppDialog>
  <ConfirmReasonDialog :confirm="confirm" />
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Plus } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Button } from "@/components/ui/button";
import AvailabilityRowEditor from "./AvailabilityRowEditor.vue";
import { useAvailabilityForm } from "./useAvailabilityForm";

const props = defineProps<{
  open: boolean;
  /** Empty = the signed-in person; set = a manager editing for somebody else. */
  userId?: string;
  title?: string;
}>();
const emit = defineEmits<{ "update:open": [boolean] }>();

const { t } = useI18n();
const confirm = useConfirmAction();
const { rows, issue, busy, loading, add, remove, submit } = useAvailabilityForm({
  confirm: async () => (await confirm.ask({ title: t("attendance.confirm.saveAvailability.title"), message: t("attendance.confirm.saveAvailability.message") })).ok,
  open: toRef(props, "open"),
  userId: toRef(props, "userId"),
  onDone: () => emit("update:open", false),
});
const rowsOf = (day: number) => rows.value.filter((row) => row.weekday === day);
</script>
