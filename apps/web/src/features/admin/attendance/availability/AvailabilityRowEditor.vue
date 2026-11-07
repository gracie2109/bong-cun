<template>
  <li class="grid gap-2 rounded-lg border bg-white p-3 sm:grid-cols-[auto_1fr_auto] sm:items-center">
    <div class="flex flex-wrap gap-2">
      <ChoiceButton :active="row.kind === 'unavailable'" @click="row.kind = 'unavailable'">{{ $t("attendance.availability.unavailable") }}</ChoiceButton>
      <ChoiceButton :active="row.kind === 'preferred'" @click="row.kind = 'preferred'">{{ $t("attendance.availability.preferred") }}</ChoiceButton>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <label class="flex min-h-11 items-center gap-2 text-sm">
        <input type="checkbox" class="size-4" :checked="row.wholeDay" @change="setWholeDay(row, ($event.target as HTMLInputElement).checked)" />
        {{ $t("attendance.availability.wholeDay") }}
      </label>
      <template v-if="!row.wholeDay">
        <Input :model-value="row.startTime ?? ''" @update:model-value="row.startTime = String($event)" type="time" class="w-28" :aria-label="$t('attendance.availability.from')" />
        <span aria-hidden="true">–</span>
        <Input :model-value="row.endTime ?? ''" @update:model-value="row.endTime = String($event)" type="time" class="w-28" :aria-label="$t('attendance.availability.to')" />
      </template>
    </div>
    <Button type="button" variant="ghost" size="icon" class="size-11" :aria-label="$t('attendance.availability.remove')" @click="emit('remove')">
      <Trash2 class="size-4" />
    </Button>
  </li>
</template>

<script lang="ts" setup>
import { Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import ChoiceButton from "../leave/ChoiceButton.vue";
import { setWholeDay, type AvailabilityDraftRow } from "./availabilityDraft";

defineProps<{ row: AvailabilityDraftRow }>();
const emit = defineEmits<{ remove: [] }>();
</script>
