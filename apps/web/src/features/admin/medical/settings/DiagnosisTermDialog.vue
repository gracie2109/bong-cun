<template>
  <AppDialog
    :open="open"
    :title="term ? $t('medical.diagnoses.edit') : $t('medical.diagnoses.add')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!draft.name.trim()"
    :busy="mutation.isPending.value"
    form-id="diagnosis-term-form"
    size="md"
    @update:open="emit('update:open', $event)"
  >
    <form id="diagnosis-term-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1">
        <Label for="diagnosis-name">{{ $t("medical.diagnoses.name") }}</Label>
        <Input id="diagnosis-name" v-model="draft.name" :placeholder="$t('medical.diagnoses.namePlaceholder')" />
      </div>

      <div class="space-y-2">
        <p class="text-sm font-medium">{{ $t("medical.diagnoses.species") }}</p>
        <p class="text-xs text-muted-foreground">{{ $t("medical.common.speciesHint") }}</p>
        <ChipPicker v-model="draft.speciesIds" :options="species" />
      </div>

      <div class="grid grid-cols-2 items-end gap-3">
        <div class="space-y-1">
          <Label for="diagnosis-sort">{{ $t("medical.common.sortOrder") }}</Label>
          <Input id="diagnosis-sort" v-model="draft.sortOrder" type="number" step="1" />
        </div>
        <label class="flex items-center gap-2 pb-2 text-sm">
          <Switch v-model="draft.isActive" :aria-label="$t('medical.common.active')" />
          {{ $t("medical.common.active") }}
        </label>
      </div>

      <label class="flex items-start gap-2 text-sm">
        <Switch v-model="draft.isContagious" :aria-label="$t('medical.diagnoses.contagious')" />
        <span>
          <span class="block font-medium">{{ $t("medical.diagnoses.contagious") }}</span>
          <span class="block text-xs text-muted-foreground">{{ $t("medical.diagnoses.contagiousHint") }}</span>
        </span>
      </label>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import ChipPicker from "@/components/common/ChipPicker.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useSaveDiagnosisTerm } from "@/features/admin/medical/queries/medical";
import { useSpeciesOptions } from "@/features/admin/pets";
import type { DiagnosisTerm } from "@bongcun/core/medical";
import { diagnosisTermInputFromDraft, draftFromDiagnosisTerm, emptyDiagnosisTermDraft } from "./diagnosisTermDraft";

const props = defineProps<{ open: boolean; term: DiagnosisTerm | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const mutation = useSaveDiagnosisTerm();
const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);

const draft = ref(emptyDiagnosisTermDraft());

// Every opening starts from the row being edited, or from an empty form.
watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) draft.value = props.term ? draftFromDiagnosisTerm(props.term) : emptyDiagnosisTermDraft();
  },
  { immediate: true }
);

const submit = async () => {
  if (!draft.value.name.trim()) return;
  try {
    await mutation.mutateAsync({ input: diagnosisTermInputFromDraft(draft.value), id: props.term?.id });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
