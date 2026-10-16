<template>
  <FilterField :label="$t('inventory.stock.expiryWindow')">
    <Select v-model="expiryWindow">
      <SelectTrigger :aria-label="$t('inventory.stock.expiryWindow')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="days in EXPIRY_WINDOWS" :key="days" :value="String(days)">
          {{ $t("inventory.stock.withinDays", { days }) }}
        </SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { EXPIRY_WINDOWS } from "@/repositories/inventory";

/** Days ahead that count as "expiring", as text for the select. */
const expiryWindow = defineModel<string>({ required: true });
</script>
