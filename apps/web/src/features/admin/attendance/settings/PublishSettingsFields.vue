<template>
  <div class="space-y-3 rounded-lg border p-3 sm:col-span-2">
    <div class="flex items-start justify-between gap-3">
      <div>
        <Label for="reg-publish">{{ $t("attendance.publish.settings.require") }}</Label>
        <p class="text-xs text-muted-foreground">{{ $t("attendance.publish.settings.requireHint") }}</p>
      </div>
      <Switch id="reg-publish" v-model:checked="form.requirePublish" :disabled="!canEdit" />
    </div>
    <div v-if="switchingOn" class="space-y-2 rounded-lg bg-amber-50 p-3 text-sm text-amber-900">
      <p>{{ $t("attendance.publish.settings.switchOnWarning") }}</p>
      <ul v-if="weeks.length" class="list-inside list-disc text-xs">
        <li v-for="week in weeks" :key="week.weekMonday">
          {{ $t("attendance.publish.settings.weekLine", { week: weekLabel(week.weekMonday), shifts: week.shifts }) }}
        </li>
      </ul>
      <label v-if="weeks.length" class="flex items-center justify-between gap-3">
        <span class="font-semibold">{{ $t("attendance.publish.settings.publishExisting") }}</span>
        <Switch v-model:checked="form.publishExisting" :aria-label="$t('attendance.publish.settings.publishExisting')" />
      </label>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import type { WeekWithShifts } from "@bongcun/core/attendance";

type PublishForm = { requirePublish: boolean; publishExisting: boolean };

defineProps<{ form: PublishForm; canEdit: boolean; switchingOn: boolean; weeks: WeekWithShifts[] }>();

const weekLabel = (monday: string) => `${monday.slice(8)}/${monday.slice(5, 7)}`;
</script>
