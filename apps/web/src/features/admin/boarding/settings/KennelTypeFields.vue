<template>
  <div class="space-y-4">
    <div class="space-y-1">
      <Label for="kennel-type-name">{{ $t("boarding.types.name") }}</Label>
      <Input id="kennel-type-name" v-model="draft.name" :placeholder="$t('boarding.types.namePlaceholder')" />
    </div>
    <div class="space-y-1">
      <Label for="kennel-type-desc">{{ $t("boarding.types.description") }}</Label>
      <Textarea id="kennel-type-desc" v-model="draft.description" rows="2" />
    </div>

    <div class="space-y-2">
      <p class="text-sm font-medium">{{ $t("boarding.types.species") }}</p>
      <p class="text-xs text-muted-foreground">{{ $t("boarding.types.speciesHint") }}</p>
      <div class="flex flex-wrap gap-x-4 gap-y-2">
        <label v-for="item in species" :key="item.id" class="flex items-center gap-2 text-sm">
          <Checkbox :checked="draft.speciesIds.includes(item.id)" @update:checked="(value: boolean | 'indeterminate') => toggleSpecies(item.id, value === true)" />
          {{ item.name }}
        </label>
      </div>
    </div>

    <div class="grid grid-cols-2 gap-3">
      <div class="space-y-1">
        <Label for="kennel-type-weight">{{ $t("boarding.types.maxWeight") }}</Label>
        <Input id="kennel-type-weight" v-model="draft.maxWeightKg" type="number" min="0" step="0.5" :placeholder="$t('boarding.types.noLimit')" />
      </div>
      <div class="space-y-1">
        <Label for="kennel-type-pets">{{ $t("boarding.types.maxPets") }}</Label>
        <Input id="kennel-type-pets" v-model="draft.maxPets" type="number" min="1" step="1" />
      </div>
      <div class="space-y-1">
        <Label for="kennel-type-price">{{ $t("boarding.types.sharedNightPrice") }}</Label>
        <Input id="kennel-type-price" v-model="draft.sharedNightPrice" type="number" min="0" step="1000" />
      </div>
      <div class="space-y-1">
        <Label for="kennel-type-extra">{{ $t("boarding.types.extraPetPrice") }}</Label>
        <Input id="kennel-type-extra" v-model="draft.sharedExtraPetNightPrice" type="number" min="0" step="1000" :placeholder="$t('boarding.types.sameAsNight')" />
      </div>
      <div class="space-y-1">
        <Label for="kennel-type-sort">{{ $t("boarding.common.sortOrder") }}</Label>
        <Input id="kennel-type-sort" v-model="draft.sortOrder" type="number" step="1" />
      </div>
    </div>

    <div class="flex flex-wrap gap-x-6 gap-y-2">
      <label class="flex items-center gap-2 text-sm">
        <Switch v-model="draft.isActive" :aria-label="$t('boarding.common.active')" />
        {{ $t("boarding.common.active") }}
      </label>
      <label class="flex items-center gap-2 text-sm">
        <Switch v-model="draft.isPublic" :aria-label="$t('boarding.types.isPublic')" />
        {{ $t("boarding.types.isPublic") }}
      </label>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import type { Species } from "@bongcun/supabase/pets";
import type { KennelTypeDraft } from "./kennelTypeDraft";

defineProps<{ species: Species[] }>();

const draft = defineModel<KennelTypeDraft>("draft", { required: true });

const toggleSpecies = (id: string, on: boolean) => {
  const rest = draft.value.speciesIds.filter((item) => item !== id);
  draft.value.speciesIds = on ? [...rest, id] : rest;
};
</script>
