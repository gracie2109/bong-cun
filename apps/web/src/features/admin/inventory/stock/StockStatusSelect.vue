<template>
  <Select v-model="status">
    <SelectTrigger class="w-48" :aria-label="$t('inventory.stock.filter')"><SelectValue /></SelectTrigger>
    <SelectContent>
      <SelectItem v-for="item in STOCK_STATUSES" :key="item" :value="item">
        {{ $t(`inventory.stock.status.${item}`) }}
      </SelectItem>
    </SelectContent>
  </Select>
</template>

<script lang="ts" setup>
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { STOCK_STATUSES, type StockStatus } from "@bongcun/supabase/inventory";

const status = defineModel<StockStatus>({ required: true });
</script>
