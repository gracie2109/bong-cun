<template>
  <FilterField :label="$t('spa.appointments.from')">
    <Input v-model="from" type="date" />
  </FilterField>
  <FilterField :label="$t('spa.appointments.to')">
    <Input v-model="to" type="date" />
  </FilterField>
  <FilterField :label="$t('spa.appointments.status')">
    <Select v-model="status">
      <SelectTrigger :aria-label="$t('spa.appointments.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in APPOINTMENT_STATUSES" :key="item" :value="item">{{ $t(`spa.status.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { APPOINTMENT_STATUSES } from "@bongcun/supabase/spa";

const from = defineModel<string>("from", { required: true });
const to = defineModel<string>("to", { required: true });
const status = defineModel<string>("status", { required: true });
</script>
