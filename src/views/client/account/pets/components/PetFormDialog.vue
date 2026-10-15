<template>
  <AppDialog
    v-model:open="open"
    :title="$t('client.pets.editTitle')"
    size="xl"
    :ok-text="$t('petCare.common.save')"
    :cancel-text="$t('petCare.common.cancel')"
    :busy="saving"
    form-id="my-pet-form"
  >
    <form id="my-pet-form" class="space-y-4" @submit.prevent="emit('submit')">
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="pet-name">{{ $t("client.pets.name") }}</Label>
          <Input id="pet-name" v-model="form.name" :class="invalid('name')" />
          <p v-if="submitted && errors.name" class="text-xs text-red-600">{{ $t("client.pets.errors.invalid_name") }}</p>
        </div>
        <div class="space-y-1.5">
          <Label>{{ $t("client.pets.species") }}</Label>
          <Select v-model="form.speciesId">
            <SelectTrigger :class="invalid('speciesId')"><SelectValue :placeholder="$t('client.pets.pickSpecies')" /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="item in species" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
            </SelectContent>
          </Select>
          <p v-if="submitted && errors.speciesId" class="text-xs text-red-600">{{ $t("client.pets.errors.invalid_species") }}</p>
        </div>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="pet-breed">{{ $t("client.pets.breed") }}</Label>
          <Input id="pet-breed" v-model="form.breed" />
        </div>
        <div class="space-y-1.5">
          <Label>{{ $t("client.pets.sex") }}</Label>
          <Select v-model="form.sex">
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="sex in PET_SEXES" :key="sex" :value="sex">{{ $t(`client.pets.sexes.${sex}`) }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="pet-birth">{{ $t("client.pets.birthDate") }}</Label>
          <Input id="pet-birth" v-model="form.birthDate" type="date" :max="today" :class="invalid('birthDate')" />
          <p v-if="submitted && errors.birthDate" class="text-xs text-red-600">{{ $t("client.pets.errors.invalid_birth_date") }}</p>
        </div>
        <div class="space-y-1.5">
          <Label for="pet-weight">{{ $t("client.pets.weightKg") }}</Label>
          <Input id="pet-weight" v-model="form.weightKg" inputmode="decimal" :class="invalid('weightKg')" />
          <p v-if="submitted && errors.weightKg" class="text-xs text-red-600">{{ $t("client.pets.errors.invalid_weight") }}</p>
        </div>
      </div>

      <label class="flex items-center gap-2 text-sm">
        <Checkbox v-model:checked="form.neutered" />
        {{ $t("client.pets.neutered") }}
      </label>

      <div class="space-y-1.5">
        <Label for="pet-allergies">{{ $t("client.pets.allergies") }}</Label>
        <Textarea id="pet-allergies" v-model="form.allergies" rows="2" />
      </div>
      <div class="space-y-1.5">
        <Label for="pet-behavior">{{ $t("client.pets.behavior") }}</Label>
        <Textarea id="pet-behavior" v-model="form.behaviorNotes" rows="2" :placeholder="$t('client.pets.behaviorHint')" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { PET_SEXES } from "@/types/account";
import type { PetErrors, PetForm } from "@/utils/account/pet";

const props = defineProps<{
  form: PetForm;
  errors: PetErrors;
  submitted: boolean;
  saving: boolean;
  species: { id: string; name: string }[];
}>();
const emit = defineEmits<{ submit: [] }>();

const open = defineModel<boolean>("open", { required: true });
const today = new Date().toISOString().slice(0, 10);
const invalid = (field: keyof PetErrors) => (props.submitted && props.errors[field] ? "border-red-500" : "");
</script>
