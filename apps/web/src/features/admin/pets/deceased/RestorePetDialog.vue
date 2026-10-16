<template>
  <AppDialog
    :open="open"
    :title="$t('petCare.pets.deceased.restoreTitle', { name: pet.name })"
    :description="$t('petCare.pets.deceased.restoreDesc')"
    :ok-text="$t('petCare.common.restore')"
    :busy="restoring.isPending.value"
    size="sm"
    @update:open="emit('update:open', $event)"
    @ok="submit"
  />
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import { useRestorePet } from "@/queries/pets";
import type { PetProfile } from "@bongcun/supabase/pets";

const props = defineProps<{ open: boolean; pet: PetProfile }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const restoring = useRestorePet();

const submit = async () => {
  try {
    await restoring.mutateAsync(props.pet.id);
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
