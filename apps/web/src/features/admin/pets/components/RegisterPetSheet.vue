<template>
  <Sheet :open="open" @update:open="close">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ $t("petCare.pets.registerSheet.title") }}</SheetTitle>
        <SheetDescription>{{ $t("petCare.pets.registerSheet.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="register-pet-form" class="flex-1 space-y-6 overflow-y-auto px-6 py-5" @submit.prevent="submit(false)">
        <RegisterOwnerSection
          v-model:search-input="owner.searchInput.value"
          v-model:selected="owner.selected.value"
          v-model:new-owner="owner.newOwner"
          :matches="owner.matches.value"
          :errors="owner.errors.value"
          :submitted="submitted"
        />

        <RegisterPetSection
          v-model:pet="pet"
          v-model:weight="weight"
          :species="species"
          :errors="errors"
          :weight-invalid="weightInvalid"
          :bracket-text="bracketText"
          :has-bracket="!!bracket"
          :submitted="submitted"
        />
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4 sm:justify-between">
        <Button type="button" variant="outline" @click="close(false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <div class="flex gap-2">
          <Button type="button" variant="secondary" :disabled="register.isPending.value" @click="submit(true)">
            {{ $t("petCare.pets.registerSheet.saveAndNext") }}
          </Button>
          <Button type="submit" form="register-pet-form" :disabled="register.isPending.value">
            {{ $t("petCare.common.save") }}
          </Button>
        </div>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { useRegisterPet } from "@/queries/pets";
import { useSpeciesOptions } from "@/queries/species";
import {
  emptyPetForm,
  formToPetInput,
  hasPetFormErrors,
  petFormErrors,
  type PetFormState,
} from "../pet-form";
import RegisterOwnerSection from "./RegisterOwnerSection.vue";
import RegisterPetSection from "./RegisterPetSection.vue";
import { useOwnerPicker } from "./useOwnerPicker";
import { useWeightHint } from "./useWeightHint";

defineProps<{ open: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean]; registered: [petId: string] }>();

const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);
const register = useRegisterPet();

const owner = useOwnerPicker();
const pet = ref<PetFormState>(emptyPetForm());
const weight = ref("");
const submitted = ref(false);

const errors = computed(() => petFormErrors(pet.value));
const { weightKg, weightInvalid, bracket, bracketText } = useWeightHint(
  computed(() => pet.value.speciesId || undefined),
  weight
);

const resetPet = () => {
  pet.value = emptyPetForm();
  weight.value = "";
  submitted.value = false;
};

const close = (value: boolean) => {
  if (!value) {
    resetPet();
    owner.reset();
  }
  emit("update:open", value);
};

const submit = async (registerAnother: boolean) => {
  submitted.value = true;
  if (owner.hasError.value || hasPetFormErrors(errors.value) || weightInvalid.value) return;

  try {
    const petId = await register.mutateAsync({
      owner: owner.toInput(),
      pet: formToPetInput(pet.value),
      weightKg: weightKg.value,
    });
    emit("registered", petId);
    if (registerAnother) {
      resetPet();
    } else {
      close(false);
    }
  } catch {
    // the mutation already showed the failure toast; keep the form open
  }
};
</script>
