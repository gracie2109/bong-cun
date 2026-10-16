<template>
  <FilterField :label="$t('pos.invoices.period')">
    <Select v-model="period">
      <SelectTrigger :aria-label="$t('pos.invoices.period')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="option in PERIODS" :key="option" :value="option">{{ $t(`pos.invoices.periods.${option}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <FilterField :label="$t('pos.invoices.status')">
    <Select v-model="status">
      <SelectTrigger :aria-label="$t('pos.invoices.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem value="paid">{{ $t("pos.status.paid") }}</SelectItem>
        <SelectItem value="unpaid">{{ $t("pos.status.unpaid") }}</SelectItem>
        <SelectItem value="cancelled">{{ $t("pos.status.cancelled") }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { PERIODS, type Period } from "./useInvoicesFilters";

const period = defineModel<Period>("period", { required: true });
const status = defineModel<string>("status", { required: true });
</script>
