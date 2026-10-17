<template>
  <AppDialog
    :open="open"
    :title="type ? $t('boarding.types.edit') : $t('boarding.types.add')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!!draftError"
    :busy="mutation.isPending.value"
    form-id="kennel-type-form"
    size="lg"
    @update:open="emit('update:open', $event)"
  >
    <form id="kennel-type-form" class="space-y-5" @submit.prevent="submit">
      <KennelTypeFields v-model:draft="draft" :species="species" />
      <BranchPriceFields v-if="branches.length" v-model:prices="draft.branchPrices" :branches="branches" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { useSaveKennelType } from "@/features/admin/boarding/queries";
import { useSpeciesOptions } from "@/features/admin/pets";
import type { Branch } from "@bongcun/supabase/users";
import type { KennelType } from "@bongcun/core/boarding";
import BranchPriceFields from "./BranchPriceFields.vue";
import KennelTypeFields from "./KennelTypeFields.vue";
import {
  draftFromKennelType,
  emptyKennelTypeDraft,
  kennelTypeDraftError,
  kennelTypeInputFromDraft,
} from "./kennelTypeDraft";

const props = defineProps<{ open: boolean; type: KennelType | null; branches: Branch[] }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const mutation = useSaveKennelType();
const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);

const draft = ref(emptyKennelTypeDraft());
const draftError = computed(() => kennelTypeDraftError(draft.value));

// Every opening starts from the row being edited, or from an empty form.
watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) draft.value = props.type ? draftFromKennelType(props.type) : emptyKennelTypeDraft();
  },
  { immediate: true }
);

const submit = async () => {
  if (draftError.value) return;
  try {
    await mutation.mutateAsync({
      input: kennelTypeInputFromDraft(draft.value, props.type?.photoUrl ?? null),
      id: props.type?.id,
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
