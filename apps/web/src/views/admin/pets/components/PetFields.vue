<template>
  <div class="space-y-4">
    <div class="space-y-2">
      <Label>{{ $t("petCare.pets.fields.species") }}</Label>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="item in species"
          :key="item.id"
          type="button"
          class="flex min-w-24 items-center justify-center gap-2 rounded-lg border px-4 py-3 text-sm font-semibold transition-colors"
          :class="
            modelValue.speciesId === item.id
              ? 'border-primary bg-primary/10 text-primary'
              : 'hover:bg-muted'
          "
          @click="set('speciesId', item.id)"
        >
          <Icon v-if="item.icon" :icon="item.icon" class="size-5" />
          {{ item.name }}
        </button>
      </div>
      <p v-if="errors.speciesId" class="text-xs text-destructive">
        {{ $t("petCare.common.required") }}
      </p>
    </div>

    <div class="space-y-2">
      <Label :for="`${idPrefix}-name`">{{ $t("petCare.pets.fields.name") }}</Label>
      <Input
        :id="`${idPrefix}-name`"
        :model-value="modelValue.name"
        :class="{ 'border-destructive': errors.name }"
        @update:model-value="set('name', String($event))"
      />
      <p v-if="errors.name" class="text-xs text-destructive">
        {{ $t("petCare.common.required") }}
      </p>
    </div>

    <div class="grid grid-cols-2 gap-3">
      <div class="space-y-2">
        <Label :for="`${idPrefix}-breed`">{{ $t("petCare.pets.fields.breed") }}</Label>
        <Input
          :id="`${idPrefix}-breed`"
          :model-value="modelValue.breed"
          @update:model-value="set('breed', String($event))"
        />
      </div>
      <div class="space-y-2">
        <Label :for="`${idPrefix}-birth`">{{ $t("petCare.pets.fields.birthDate") }}</Label>
        <Input
          :id="`${idPrefix}-birth`"
          type="date"
          :max="today"
          :model-value="modelValue.birthDate"
          @update:model-value="set('birthDate', String($event))"
        />
      </div>
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="space-y-2">
        <Label>{{ $t("petCare.pets.fields.sex") }}</Label>
        <div class="flex gap-1 rounded-lg border p-1">
          <button
            v-for="sex in sexes"
            :key="sex"
            type="button"
            class="rounded-md px-3 py-1.5 text-sm font-medium transition-colors"
            :class="
              modelValue.sex === sex ? 'bg-primary text-primary-foreground' : 'hover:bg-muted'
            "
            @click="set('sex', sex)"
          >
            {{ $t(`petCare.sex.${sex}`) }}
          </button>
        </div>
      </div>
      <label class="flex items-center gap-2 text-sm font-medium">
        <Switch
          :checked="modelValue.neutered"
          @update:checked="set('neutered', Boolean($event))"
        />
        {{ $t("petCare.pets.fields.neutered") }}
      </label>
    </div>

    <div class="space-y-2">
      <Label :for="`${idPrefix}-chip`">{{ $t("petCare.pets.fields.microchip") }}</Label>
      <Input
        :id="`${idPrefix}-chip`"
        :model-value="modelValue.microchip"
        @update:model-value="set('microchip', String($event))"
      />
    </div>

    <div class="space-y-2">
      <Label :for="`${idPrefix}-allergies`">{{ $t("petCare.pets.fields.allergies") }}</Label>
      <Textarea
        :id="`${idPrefix}-allergies`"
        class="resize-none"
        :model-value="modelValue.allergies"
        @update:model-value="set('allergies', String($event))"
      />
    </div>

    <div class="space-y-2">
      <Label :for="`${idPrefix}-behavior`">{{ $t("petCare.pets.fields.behavior") }}</Label>
      <Textarea
        :id="`${idPrefix}-behavior`"
        class="resize-none"
        :model-value="modelValue.behaviorNotes"
        @update:model-value="set('behaviorNotes', String($event))"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import type { PetSex } from "@/repositories/pets";
import type { Species } from "@/repositories/species";
import { todayInput } from "../format";
import type { PetFormErrors, PetFormState } from "../pet-form";

const props = defineProps<{
  modelValue: PetFormState;
  species: Species[];
  errors: PetFormErrors;
  /** Keeps element ids unique when two forms are on the page. */
  idPrefix: string;
}>();

const emit = defineEmits<{ "update:modelValue": [value: PetFormState] }>();

const sexes: PetSex[] = ["male", "female", "unknown"];
const today = todayInput();

const set = <K extends keyof PetFormState>(key: K, value: PetFormState[K]) =>
  emit("update:modelValue", { ...props.modelValue, [key]: value });
</script>
