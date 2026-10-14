<template>
  <FilterField :label="$t('pageFields.customers.sortBy')">
    <Select v-model="sort">
      <SelectTrigger><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="option in SORT_OPTIONS" :key="option" :value="option">
          {{ $t(`pageFields.customers.sort.${option}`) }}
        </SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { USER_SORT, type UserSort } from "@/repositories/users";

const SORT_OPTIONS = Object.values(USER_SORT);

const sort = defineModel<UserSort>({ required: true });
</script>
