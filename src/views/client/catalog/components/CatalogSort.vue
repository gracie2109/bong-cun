<template>
  <Select :model-value="modelValue" @update:model-value="(value) => emit('update:modelValue', value as CatalogSort)">
    <SelectTrigger class="w-[170px]" :aria-label="$t('client.catalog.sortBy')">
      <SelectValue />
    </SelectTrigger>
    <SelectContent>
      <SelectItem v-for="sort in CATALOG_SORTS" :key="sort" :value="sort">
        {{ $t(`client.catalog.sort.${sort}`) }}
      </SelectItem>
    </SelectContent>
  </Select>
</template>

<script lang="ts" setup>
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { CATALOG_SORTS, type CatalogSort } from "@/types/catalog";

defineProps<{ modelValue: CatalogSort }>();
const emit = defineEmits<{ "update:modelValue": [value: CatalogSort] }>();
</script>
