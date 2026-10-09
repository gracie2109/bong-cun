<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input
        v-model="search"
        class="pl-9"
        :placeholder="$t('petCare.pets.searchPlaceholder')"
      />
    </div>

    <Select v-model="speciesFilter">
      <SelectTrigger class="w-40" :aria-label="$t('petCare.pets.filterSpecies')">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in species" :key="item.id" :value="item.id">
          {{ item.name }}
        </SelectItem>
      </SelectContent>
    </Select>

    <Select v-model="bracketFilter" :disabled="speciesFilter === FILTER_ALL">
      <SelectTrigger class="w-44" :aria-label="$t('petCare.pets.filterBracket')">
        <SelectValue :placeholder="$t('petCare.pets.filterBracket')" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in brackets" :key="item.id" :value="item.id">
          {{ item.label }}
        </SelectItem>
      </SelectContent>
    </Select>

    <Select v-model="statusFilter">
      <SelectTrigger class="w-44" :aria-label="$t('petCare.pets.filterStatus')">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem v-for="status in PET_STATUSES" :key="status" :value="status">
          {{ $t(`petCare.status.${status}`) }}
        </SelectItem>
      </SelectContent>
    </Select>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { PetStatus } from "@/repositories/pets";
import { PET_STATUSES } from "../usePetsFilters";
import { FILTER_ALL } from "@/lib/listing";

defineProps<{
  species: { id: string; name: string }[];
  brackets: { id: string; label: string }[];
}>();

const search = defineModel<string>("search", { required: true });
const speciesFilter = defineModel<string>("speciesFilter", { required: true });
const bracketFilter = defineModel<string>("bracketFilter", { required: true });
const statusFilter = defineModel<PetStatus>("statusFilter", { required: true });
</script>
