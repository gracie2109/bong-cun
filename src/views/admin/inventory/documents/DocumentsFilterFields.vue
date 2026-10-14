<template>
  <FilterField :label="$t('inventory.documents.type')">
    <Select v-model="docType">
      <SelectTrigger :aria-label="$t('inventory.documents.type')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="type in DOC_TYPES" :key="type" :value="type">{{ $t(`inventory.documents.types.${type}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <FilterField :label="$t('pos.invoices.status')">
    <Select v-model="status">
      <SelectTrigger :aria-label="$t('pos.invoices.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in DOC_STATUSES" :key="item" :value="item">{{ $t(`inventory.documents.status.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { DOC_STATUSES, DOC_TYPES } from "@/repositories/inventory";

const docType = defineModel<string>("docType", { required: true });
const status = defineModel<string>("status", { required: true });
</script>
