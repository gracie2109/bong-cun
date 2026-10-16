<template>
  <FilterField :label="$t('medical.visits.from')">
    <Input v-model="from" type="date" />
  </FilterField>
  <FilterField :label="$t('medical.visits.to')">
    <Input v-model="to" type="date" />
  </FilterField>
  <FilterField :label="$t('medical.visits.status')">
    <Select v-model="status">
      <SelectTrigger :aria-label="$t('medical.visits.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in VISIT_STATUSES" :key="item" :value="item">{{ $t(`medical.status.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
  <FilterField :label="$t('medical.visits.vet')">
    <Select v-model="vetId">
      <SelectTrigger :aria-label="$t('medical.visits.vet')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="vet in vets" :key="vet.id" :value="vet.id">{{ vet.name }}</SelectItem>
      </SelectContent>
    </Select>
  </FilterField>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { VISIT_STATUSES, type Vet } from "@/types/medicalVisit";

defineProps<{ vets: Vet[] }>();
const from = defineModel<string>("from", { required: true });
const to = defineModel<string>("to", { required: true });
const status = defineModel<string>("status", { required: true });
const vetId = defineModel<string>("vetId", { required: true });
</script>
