<template>
  <fieldset class="space-y-3" :disabled="readonly">
    <div class="space-y-1.5">
      <Label for="owner-instructions">{{ $t("medical.record.instructions") }}</Label>
      <Textarea id="owner-instructions" v-model="draft.ownerInstructions" rows="3" :placeholder="$t('medical.record.instructionsHint')" />
    </div>
    <div class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label>{{ $t("medical.record.outcome") }}</Label>
        <Select v-model="outcome">
          <SelectTrigger :aria-label="$t('medical.record.outcome')"><SelectValue :placeholder="$t('medical.record.outcomePlaceholder')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="item in VISIT_OUTCOMES" :key="item" :value="item">{{ $t(`medical.outcome.${item}`) }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div v-if="draft.outcome === 'recheck'" class="space-y-1.5">
        <Label for="recheck-on">{{ $t("medical.record.recheckOn") }}</Label>
        <Input id="recheck-on" v-model="draft.recheckOn" type="date" />
      </div>
    </div>
  </fieldset>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { VISIT_OUTCOMES, type VisitOutcome } from "@bongcun/core/medical";
import type { RecordDraft } from "./recordDraft";

defineProps<{ readonly: boolean }>();
const draft = defineModel<RecordDraft>("draft", { required: true });

const outcome = computed({
  get: () => draft.value.outcome || undefined,
  set: (value: string | undefined) => {
    draft.value.outcome = (value as VisitOutcome | undefined) ?? "";
  },
});
</script>
