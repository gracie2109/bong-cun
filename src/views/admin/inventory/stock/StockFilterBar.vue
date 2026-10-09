<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('products.searchPlaceholder')" />
    </div>
    <Select v-model="status">
      <SelectTrigger class="w-48" :aria-label="$t('inventory.stock.filter')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="item in STOCK_STATUSES" :key="item" :value="item">
          {{ $t(`inventory.stock.status.${item}`) }}
        </SelectItem>
      </SelectContent>
    </Select>
    <Select v-model="expiryWindow">
      <SelectTrigger class="w-44" :aria-label="$t('inventory.stock.expiryWindow')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="days in EXPIRY_WINDOWS" :key="days" :value="String(days)">
          {{ $t("inventory.stock.withinDays", { days }) }}
        </SelectItem>
      </SelectContent>
    </Select>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { EXPIRY_WINDOWS, STOCK_STATUSES, type StockStatus } from "@/repositories/inventory";

const search = defineModel<string>("search", { required: true });
const status = defineModel<StockStatus>("status", { required: true });
/** Days ahead that count as "expiring", as text for the select. */
const expiryWindow = defineModel<string>("expiryWindow", { required: true });
</script>
