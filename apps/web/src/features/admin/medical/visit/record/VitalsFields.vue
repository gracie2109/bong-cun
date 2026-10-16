<template>
  <fieldset class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4" :disabled="readonly">
    <div class="space-y-1.5">
      <Label for="vital-weight">{{ $t("medical.vitals.weight") }} (kg)</Label>
      <Input id="vital-weight" v-model="draft.weight" inputmode="decimal" />
    </div>
    <div class="space-y-1.5">
      <Label for="vital-temp">{{ $t("medical.vitals.temperature") }} (°C)</Label>
      <Input id="vital-temp" v-model="draft.temperature" inputmode="decimal" />
    </div>
    <div class="space-y-1.5">
      <Label for="vital-hr">{{ $t("medical.vitals.heartRate") }}</Label>
      <Input id="vital-hr" v-model="draft.heartRate" inputmode="numeric" />
    </div>
    <div class="space-y-1.5">
      <Label for="vital-rr">{{ $t("medical.vitals.respRate") }}</Label>
      <Input id="vital-rr" v-model="draft.respRate" inputmode="numeric" />
    </div>
    <div class="space-y-1.5 sm:col-span-2 lg:col-span-4">
      <Label for="vital-note">{{ $t("medical.vitals.note") }}</Label>
      <Input id="vital-note" v-model="draft.vitalsNote" />
    </div>
  </fieldset>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { RecordDraft } from "./recordDraft";

defineProps<{ readonly: boolean }>();
const draft = defineModel<RecordDraft>("draft", { required: true });
</script>
