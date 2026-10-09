<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('pos.invoices.searchPlaceholder')" />
    </div>
    <Select v-model="period">
      <SelectTrigger class="w-40" :aria-label="$t('pos.invoices.period')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="option in PERIODS" :key="option" :value="option">{{ $t(`pos.invoices.periods.${option}`) }}</SelectItem>
      </SelectContent>
    </Select>
    <Select v-model="status">
      <SelectTrigger class="w-40" :aria-label="$t('pos.invoices.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem value="paid">{{ $t("pos.status.paid") }}</SelectItem>
        <SelectItem value="cancelled">{{ $t("pos.status.cancelled") }}</SelectItem>
      </SelectContent>
    </Select>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { PERIODS, type Period } from "./useInvoicesFilters";

const search = defineModel<string>("search", { required: true });
const period = defineModel<Period>("period", { required: true });
const status = defineModel<string>("status", { required: true });
</script>
