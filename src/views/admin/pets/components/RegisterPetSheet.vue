<template>
  <Sheet :open="open" @update:open="close">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ $t("petCare.pets.registerSheet.title") }}</SheetTitle>
        <SheetDescription>{{ $t("petCare.pets.registerSheet.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="register-pet-form" class="flex-1 space-y-6 overflow-y-auto px-6 py-5" @submit.prevent="submit(false)">
        <section class="space-y-3">
          <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {{ $t("petCare.pets.registerSheet.ownerSection") }}
          </h3>

          <div
            v-if="selected"
            class="flex items-center justify-between gap-3 rounded-lg border bg-primary/5 p-3"
          >
            <div class="min-w-0">
              <p class="truncate font-semibold">{{ selected.fullName }}</p>
              <p class="text-xs text-muted-foreground">
                {{ selected.phone }} ·
                {{ $t("petCare.pets.registerSheet.matchPets", { n: selected.petCount }) }}
              </p>
            </div>
            <Button type="button" size="sm" variant="outline" @click="clearSelected">
              {{ $t("petCare.pets.registerSheet.change") }}
            </Button>
          </div>

          <template v-else>
            <div class="space-y-2">
              <Label for="register-owner-phone">{{ $t("petCare.pets.registerSheet.phone") }}</Label>
              <Input
                id="register-owner-phone"
                v-model="phoneText"
                inputmode="tel"
                :placeholder="$t('petCare.pets.registerSheet.phonePlaceholder')"
              />
            </div>

            <ul v-if="matches.length" class="divide-y rounded-lg border">
              <li
                v-for="match in matches"
                :key="match.id"
                class="flex items-center justify-between gap-3 px-3 py-2"
              >
                <div class="min-w-0">
                  <p class="truncate text-sm font-semibold">{{ match.fullName }}</p>
                  <p class="text-xs text-muted-foreground">
                    {{ match.phone }} ·
                    {{ $t("petCare.pets.registerSheet.matchPets", { n: match.petCount }) }}
                  </p>
                </div>
                <Button type="button" size="sm" @click="selected = match">
                  {{ $t("petCare.pets.registerSheet.choose") }}
                </Button>
              </li>
            </ul>

            <div class="space-y-3 rounded-lg border border-dashed p-3">
              <p class="text-xs text-muted-foreground">
                <span class="font-semibold text-foreground">
                  {{ $t("petCare.pets.registerSheet.newCustomer") }}.
                </span>
                {{ $t("petCare.pets.registerSheet.walkIn") }}
              </p>
              <div class="space-y-2">
                <Label for="register-owner-name">{{ $t("petCare.pets.registerSheet.fullName") }}</Label>
                <Input id="register-owner-name" v-model="newOwner.fullName" />
              </div>
              <div class="space-y-2">
                <Label for="register-owner-email">{{ $t("petCare.pets.registerSheet.email") }}</Label>
                <Input id="register-owner-email" v-model="newOwner.email" type="email" />
              </div>
            </div>
          </template>
          <p v-if="submitted && ownerError" class="text-xs text-destructive">{{ ownerError }}</p>
        </section>

        <section class="space-y-4">
          <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {{ $t("petCare.pets.registerSheet.petSection") }}
          </h3>
          <PetFields
            v-model="pet"
            :species="species"
            :errors="submitted ? errors : noErrors"
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
            <p v-if="bracketText" class="text-xs font-medium" :class="bracket ? 'text-primary' : 'text-amber-600'">
              {{ bracketText }}
            </p>
          </div>
        </section>
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
import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { useCustomerSearch } from "@/queries/customers";
import { useRegisterPet } from "@/queries/pets";
import { useSpeciesOptions } from "@/queries/species";
import { useWeightBrackets } from "@/queries/weightBrackets";
import { digitsOf, type CustomerMatch } from "@/repositories/customers";
import type { RegisterOwner } from "@/repositories/pets";
import { findBracket } from "@/repositories/weightBrackets";
import {
  emptyPetForm,
  formToPetInput,
  hasPetFormErrors,
  petFormErrors,
  type PetFormState,
} from "../pet-form";
import PetFields from "./PetFields.vue";

const MIN_PHONE_DIGITS = 8;
const MAX_PHONE_DIGITS = 15;
const SEARCH_DEBOUNCE_MS = 300;

defineProps<{ open: boolean }>();
const emit = defineEmits<{ "update:open": [value: boolean]; registered: [petId: string] }>();

const { t } = useI18n();
const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);
const register = useRegisterPet();

const phoneText = ref("");
const selected = ref<CustomerMatch | null>(null);
const newOwner = reactive({ fullName: "", email: "" });
const pet = ref<PetFormState>(emptyPetForm());
const weight = ref("");
const submitted = ref(false);
const noErrors = { name: false, speciesId: false };

const searchText = refDebounced(phoneText, SEARCH_DEBOUNCE_MS);
const matchesQuery = useCustomerSearch(searchText);
const matches = computed(() => matchesQuery.data.value ?? []);

const speciesId = computed(() => pet.value.speciesId || undefined);
const bracketsQuery = useWeightBrackets(speciesId, { enabled: computed(() => !!speciesId.value) });
const weightKg = computed(() => (weight.value === "" ? null : Number(weight.value)));
const weightInvalid = computed(
  () => weightKg.value !== null && (Number.isNaN(weightKg.value) || weightKg.value <= 0)
);
const bracket = computed(() =>
  weightKg.value !== null && !weightInvalid.value && speciesId.value
    ? findBracket(bracketsQuery.data.value ?? [], weightKg.value)
    : undefined
);
const bracketText = computed(() => {
  if (weightKg.value === null || weightInvalid.value || !speciesId.value) return "";
  return bracket.value
    ? t("petCare.pets.fields.weightBracket", { label: bracket.value.label })
    : t("petCare.pets.fields.noBracket");
});

const errors = computed(() => petFormErrors(pet.value));

const ownerError = computed((): string | null => {
  if (selected.value) return null;
  if (newOwner.fullName.trim().length === 0) return t("petCare.pets.registerSheet.errOwner");
  const digits = digitsOf(phoneText.value).length;
  if (digits < MIN_PHONE_DIGITS || digits > MAX_PHONE_DIGITS) {
    return t("petCare.pets.registerSheet.errPhone");
  }
  return null;
});

const clearSelected = () => {
  selected.value = null;
};

const resetPet = () => {
  pet.value = emptyPetForm();
  weight.value = "";
  submitted.value = false;
};

const resetAll = () => {
  resetPet();
  phoneText.value = "";
  newOwner.fullName = "";
  newOwner.email = "";
  selected.value = null;
};

const close = (value: boolean) => {
  if (!value) resetAll();
  emit("update:open", value);
};

// An existing customer picked from the list wins over whatever was typed for a new one.
const ownerInput = (): RegisterOwner =>
  selected.value
    ? { id: selected.value.id }
    : {
        fullName: newOwner.fullName.trim(),
        phone: phoneText.value.trim(),
        email: newOwner.email.trim() || null,
      };

const submit = async (registerAnother: boolean) => {
  submitted.value = true;
  if (ownerError.value || hasPetFormErrors(errors.value) || weightInvalid.value) return;

  try {
    const petId = await register.mutateAsync({
      owner: ownerInput(),
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

// Choosing a customer from the list replaces the typed phone with theirs.
watch(selected, (match) => {
  if (match) phoneText.value = match.phone;
});
</script>
