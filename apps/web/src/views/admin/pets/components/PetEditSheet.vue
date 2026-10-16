<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ $t("petCare.pets.detail.editProfile") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ pet.name }}</SheetDescription>
      </SheetHeader>

      <form id="edit-pet-form" class="flex-1 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <PetFields
          v-model="form"
          :species="species"
          :errors="submitted ? errors : noErrors"
          id-prefix="edit"
        />
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" form="edit-pet-form" :disabled="update.isPending.value">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { useUpdatePet } from "@/queries/pets";
import { useSpeciesOptions } from "@/queries/species";
import type { PetProfile } from "@/repositories/pets";
import {
  formToPetInput,
  hasPetFormErrors,
  petFormErrors,
  petToForm,
  type PetFormState,
} from "../pet-form";
import PetFields from "./PetFields.vue";

const props = defineProps<{ open: boolean; pet: PetProfile }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

// A pet's current species stays selectable even if it was archived since.
const speciesQuery = useSpeciesOptions(true);
const species = computed(() => speciesQuery.data.value ?? []);
const update = useUpdatePet();

const form = ref<PetFormState>(petToForm(props.pet));
const submitted = ref(false);
const noErrors = { name: false, speciesId: false };
const errors = computed(() => petFormErrors(form.value));

// Opening the sheet always starts from the saved profile, dropping abandoned edits.
watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    form.value = petToForm(props.pet);
    submitted.value = false;
  }
);

const submit = async () => {
  submitted.value = true;
  if (hasPetFormErrors(errors.value)) return;

  try {
    await update.mutateAsync({ id: props.pet.id, input: formToPetInput(form.value) });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast; keep the form open
  }
};
</script>
