<template>
  <FilterField :label="$t('petCare.services.filterSpecies')">
    <Select v-model="speciesId">
      <SelectTrigger :aria-label="$t('petCare.services.filterSpecies')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in species" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <FilterField :label="$t('petCare.services.filterType')">
    <Select v-model="type">
      <SelectTrigger :aria-label="$t('petCare.services.filterType')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem value="by_weight">{{ $t("petCare.services.typeByWeight") }}</SelectItem>
        <SelectItem value="all">{{ $t("petCare.services.typeAll") }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <label class="flex items-center gap-2 self-end pb-2 text-sm text-muted-foreground">
    <Switch v-model="showArchived" />
    {{ $t("petCare.services.showArchived") }}
  </label>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { FILTER_ALL } from "@/lib/listing";

defineProps<{ species: { id: string; name: string }[] }>();

const speciesId = defineModel<string>("speciesId", { required: true });
const type = defineModel<string>("type", { required: true });
const showArchived = defineModel<boolean>("showArchived", { required: true });
</script>
