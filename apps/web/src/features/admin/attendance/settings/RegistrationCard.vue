<template>
  <section class="rounded-xl border bg-white">
    <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("attendance.registrationSettings.title") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("attendance.registrationSettings.hint") }}</p>
      </div>
      <Button v-if="canEdit" size="sm" :disabled="!dirty || !valid || saving" @click="save">
        <Loader2 v-if="saving" class="mr-1 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </header>

    <div v-if="form" class="grid gap-4 p-4 sm:grid-cols-2">
      <div class="flex items-start justify-between gap-3 rounded-lg border p-3 sm:col-span-2">
        <div>
          <Label for="reg-open">{{ $t("attendance.registrationSettings.isOpen") }}</Label>
          <p class="text-xs text-muted-foreground">{{ $t("attendance.registrationSettings.isOpenHint") }}</p>
        </div>
        <Switch id="reg-open" v-model:checked="form.isOpen" :disabled="!canEdit" />
      </div>
      <div class="space-y-1">
        <Label for="reg-weeks">{{ $t("attendance.registrationSettings.weeksAhead") }}</Label>
        <Input id="reg-weeks" v-model.number="form.weeksAhead" type="number" min="1" max="6" step="1" inputmode="numeric" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("attendance.registrationSettings.weeksAheadHint") }}</p>
      </div>
      <div class="space-y-1">
        <Label for="reg-close">{{ $t("attendance.registrationSettings.closeDaysBefore") }}</Label>
        <Input id="reg-close" v-model.number="form.closeDaysBefore" type="number" min="0" max="14" step="1" inputmode="numeric" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("attendance.registrationSettings.closeDaysBeforeHint") }}</p>
      </div>
      <div class="space-y-1">
        <div class="flex items-center justify-between gap-3">
          <Label for="reg-max">{{ $t("attendance.registrationSettings.maxShifts") }}</Label>
          <Switch v-model:checked="form.limited" :disabled="!canEdit" :aria-label="$t('attendance.registrationSettings.maxShifts')" />
        </div>
        <Input id="reg-max" v-model.number="form.maxShiftsPerWeek" type="number" min="1" max="21" step="1" inputmode="numeric" :disabled="!canEdit || !form.limited" />
        <p class="text-xs text-muted-foreground">{{ $t("attendance.registrationSettings.maxShiftsHint") }}</p>
      </div>
      <PublishSettingsFields :form="form" :can-edit="canEdit" :switching-on="switchingOn" :weeks="weeksWithShifts" />
      <div class="space-y-1">
        <Label for="reg-note">{{ $t("attendance.registrationSettings.staffNote") }}</Label>
        <Input id="reg-note" v-model="form.staffNote" maxlength="300" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("attendance.registrationSettings.staffNoteHint") }}</p>
      </div>
    </div>
    <p v-else-if="!loading" class="px-4 py-6 text-center text-sm text-muted-foreground">{{ $t("attendance.rules.unavailable") }}</p>
    <p v-if="form && !valid" class="px-4 pb-4 text-sm text-destructive">{{ $t("attendance.errors.bad_input") }}</p>
  </section>
  <ConfirmReasonDialog :confirm="confirm" />
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2 } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useWeeksWithShifts } from "@/features/admin/attendance/queries";
import PublishSettingsFields from "./PublishSettingsFields.vue";
import { useRegistrationSettingsForm } from "./useRegistrationSettingsForm";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();
const { t } = useI18n();
const confirm = useConfirmAction();
const branch = computed(() => props.branchId);
const { form, switchingOn, dirty, valid, save, saving, loading } = useRegistrationSettingsForm(
  branch,
  async () => (await confirm.ask({ title: t("attendance.confirm.saveRegistration.title"), message: t("attendance.confirm.saveRegistration.message") })).ok
);
const weeksQuery = useWeeksWithShifts(branch, switchingOn);
const weeksWithShifts = computed(() => weeksQuery.data.value ?? []);
</script>
