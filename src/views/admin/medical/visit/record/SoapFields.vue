<template>
  <fieldset class="grid gap-3 lg:grid-cols-2" :disabled="readonly">
    <div v-for="field in FIELDS" :key="field" class="space-y-1.5">
      <Label :for="`soap-${field}`">{{ $t(`medical.soap.${field}`) }}</Label>
      <Textarea :id="`soap-${field}`" v-model="draft[field]" rows="4" :placeholder="$t(`medical.soap.${field}Hint`)" />
    </div>
  </fieldset>
</template>

<script lang="ts" setup>
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { RecordDraft } from "./recordDraft";

// S = what the owner says, O = what the vet finds, A = the assessment, P = the plan.
const FIELDS = ["subjective", "objective", "assessment", "plan"] as const;

defineProps<{ readonly: boolean }>();
const draft = defineModel<RecordDraft>("draft", { required: true });
</script>
