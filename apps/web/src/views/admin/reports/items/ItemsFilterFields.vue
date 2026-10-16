<template>
  <FilterField :label="$t('reports.items.sort')">
    <Select v-model="sort">
      <SelectTrigger :aria-label="$t('reports.items.sort')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="item in SORTS" :key="item" :value="item">{{ $t(`reports.sorts.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { ItemSort } from "@bongcun/supabase/reports";

const sort = defineModel<ItemSort>({ required: true });

const SORTS: ItemSort[] = ["revenue", "qty", "profit"];
</script>
