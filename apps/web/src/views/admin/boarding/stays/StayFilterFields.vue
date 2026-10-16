<template>
  <FilterField :label="$t('boarding.stays.from')">
    <Input v-model="from" type="date" />
  </FilterField>
  <FilterField :label="$t('boarding.stays.to')">
    <Input v-model="to" type="date" />
  </FilterField>
  <FilterField :label="$t('boarding.stays.status')">
    <Select v-model="status">
      <SelectTrigger :aria-label="$t('boarding.stays.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in STAY_STATUSES" :key="item" :value="item">{{ $t(`boarding.status.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { STAY_STATUSES } from "@/types/boarding";

const from = defineModel<string>("from", { required: true });
const to = defineModel<string>("to", { required: true });
const status = defineModel<string>("status", { required: true });
</script>
