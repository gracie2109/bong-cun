<template>
  <FilterField :label="$t('petCare.pets.filterSpecies')">
    <Select :model-value="speciesId" @update:model-value="pickSpecies">
      <SelectTrigger :aria-label="$t('petCare.pets.filterSpecies')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in species" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <FilterField :label="$t('petCare.pets.filterBracket')">
    <Select v-model="bracketId" :disabled="speciesId === FILTER_ALL">
      <SelectTrigger :aria-label="$t('petCare.pets.filterBracket')">
        <SelectValue :placeholder="$t('petCare.pets.filterBracket')" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in brackets" :key="item.id" :value="item.id">{{ item.label }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <FilterField :label="$t('petCare.pets.filterStatus')">
    <Select v-model="status">
      <SelectTrigger :aria-label="$t('petCare.pets.filterStatus')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="item in PET_STATUSES" :key="item" :value="item">{{ $t(`petCare.status.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import type { PetStatus } from "@/repositories/pets";
import { PET_STATUSES } from "../usePetsFilters";

defineProps<{
  species: { id: string; name: string }[];
  brackets: { id: string; label: string }[];
}>();

const speciesId = defineModel<string>("speciesId", { required: true });
const bracketId = defineModel<string>("bracketId", { required: true });
const status = defineModel<PetStatus>("status", { required: true });

// A bracket of another species no longer applies.
const pickSpecies = (value: unknown) => {
  speciesId.value = String(value);
  bracketId.value = FILTER_ALL;
};
</script>
