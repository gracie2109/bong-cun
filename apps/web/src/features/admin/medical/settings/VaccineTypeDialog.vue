<template>
  <AppDialog
    :open="open"
    :title="type ? $t('medical.vaccines.edit') : $t('medical.vaccines.add')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!!draftError"
    :busy="mutation.isPending.value"
    form-id="vaccine-type-form"
    size="lg"
    @update:open="emit('update:open', $event)"
  >
    <form id="vaccine-type-form" @submit.prevent="submit">
      <VaccineTypeFields v-model:draft="draft" :species="species" />
      <p v-if="draftError && draftError !== 'name'" class="mt-3 text-sm text-destructive">{{ $t(`medical.vaccines.errors.${draftError}`) }}</p>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { useSaveVaccineType } from "@/queries/medical";
import { useSpeciesOptions } from "@/queries/species";
import type { VaccineType } from "@bongcun/core/medical";
import VaccineTypeFields from "./VaccineTypeFields.vue";
import {
  draftFromVaccineType,
  emptyVaccineTypeDraft,
  vaccineTypeDraftError,
  vaccineTypeInputFromDraft,
} from "./vaccineTypeDraft";

const props = defineProps<{ open: boolean; type: VaccineType | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const mutation = useSaveVaccineType();
const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);

const draft = ref(emptyVaccineTypeDraft());
const draftError = computed(() => vaccineTypeDraftError(draft.value));

// Every opening starts from the row being edited, or from an empty form.
watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) draft.value = props.type ? draftFromVaccineType(props.type) : emptyVaccineTypeDraft();
  },
  { immediate: true }
);

const submit = async () => {
  if (draftError.value) return;
  try {
    await mutation.mutateAsync({ input: vaccineTypeInputFromDraft(draft.value), id: props.type?.id });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
