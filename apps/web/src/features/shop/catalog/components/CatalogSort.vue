<template>
  <Select :model-value="modelValue" @update:model-value="(value) => emit('update:modelValue', value as CatalogSort)">
    <SelectTrigger
      class="h-11 w-auto shrink-0 gap-2 rounded-full border-border bg-white px-4 font-medium shadow-none sm:w-[180px]"
      :aria-label="$t('client.catalog.sortBy')"
    >
      <ArrowUpDown class="size-4 shrink-0 text-muted-foreground sm:hidden" />
      <span class="hidden sm:inline"><SelectValue /></span>
    </SelectTrigger>
    <SelectContent align="end" class="rounded-xl">
      <SelectItem v-for="sort in CATALOG_SORTS" :key="sort" :value="sort" class="h-10 rounded-lg">
        {{ $t(`client.catalog.sort.${sort}`) }}
      </SelectItem>
    </SelectContent>
  </Select>
</template>

<script lang="ts" setup>
import { ArrowUpDown } from "lucide-vue-next";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { CATALOG_SORTS, type CatalogSort } from "@bongcun/core/shop";

defineProps<{ modelValue: CatalogSort }>();
const emit = defineEmits<{ "update:modelValue": [value: CatalogSort] }>();
</script>
