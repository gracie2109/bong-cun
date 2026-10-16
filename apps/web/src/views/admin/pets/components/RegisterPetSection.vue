<template>
  <section class="space-y-4">
    <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
      {{ $t("petCare.pets.registerSheet.petSection") }}
    </h3>
    <PetFields
      v-model="pet"
      :species="species"
      :errors="submitted ? errors : NO_ERRORS"
      id-prefix="register"
    />

    <div class="space-y-2">
      <Label for="register-weight">{{ $t("petCare.pets.fields.weight") }}</Label>
      <Input
        id="register-weight"
        v-model="weight"
        type="number"
        step="0.1"
        min="0"
        inputmode="decimal"
        :class="{ 'border-destructive': submitted && weightInvalid }"
      />
      <p v-if="bracketText" class="text-xs font-medium" :class="hasBracket ? 'text-primary' : 'text-amber-600'">
        {{ bracketText }}
      </p>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { Species } from "@/repositories/species";
import type { PetFormState } from "../pet-form";
import PetFields from "./PetFields.vue";

const NO_ERRORS = { name: false, speciesId: false };

defineProps<{
  species: Species[];
  errors: { name: boolean; speciesId: boolean };
  weightInvalid: boolean;
  bracketText: string;
  /** Whether the weight falls in a known bracket, which colors the hint. */
  hasBracket: boolean;
  /** Whether a save was attempted, which shows the errors. */
  submitted: boolean;
}>();

const pet = defineModel<PetFormState>("pet", { required: true });
const weight = defineModel<string>("weight", { required: true });
</script>
