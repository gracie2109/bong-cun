<template>
  <section class="grid gap-3 sm:grid-cols-2">
    <div class="space-y-1.5">
      <Label for="boarding-in-date">{{ $t("boarding.dialog.arrival") }}</Label>
      <div class="flex gap-2">
        <Input id="boarding-in-date" v-model="draft.inDate" type="date" :min="todayKey()" @update:model-value="keepOrder" />
        <Input v-model="draft.inTime" type="time" step="900" class="w-32" :aria-label="$t('boarding.dialog.arrivalTime')" />
      </div>
      <p v-if="rules" class="text-xs text-muted-foreground">{{ $t("boarding.dialog.acceptedFrom", { time: rules.checkInFrom }) }}</p>
    </div>
    <div class="space-y-1.5">
      <Label for="boarding-out-date">{{ $t("boarding.dialog.departure") }}</Label>
      <div class="flex gap-2">
        <Input id="boarding-out-date" v-model="draft.outDate" type="date" :min="draft.inDate" />
        <Input v-model="draft.outTime" type="time" step="900" class="w-32" :aria-label="$t('boarding.dialog.departureTime')" />
      </div>
      <p v-if="rules" class="text-xs text-muted-foreground">
        {{ $t("boarding.dialog.freeUntil", { time: rules.checkOutBy, nights: nights }) }}
      </p>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { BoardingRules } from "@bongcun/core/boarding";
import { nightsBetween, todayKey } from "../format";
import type { StayDraft } from "./stayDraft";

defineProps<{ rules: BoardingRules | undefined }>();

const draft = defineModel<StayDraft>("draft", { required: true });

const nights = computed(() => nightsBetween(draft.value.inDate, draft.value.outDate));

// Moving the arrival past the departure pulls the departure along.
const keepOrder = () => {
  if (draft.value.outDate && draft.value.outDate < draft.value.inDate) draft.value.outDate = draft.value.inDate;
};
</script>
