<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('inventory.documents.searchPlaceholder')" />
    </div>
    <Select v-model="docType">
      <SelectTrigger class="w-44" :aria-label="$t('inventory.documents.type')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="type in DOC_TYPES" :key="type" :value="type">{{ $t(`inventory.documents.types.${type}`) }}</SelectItem>
      </SelectContent>
    </Select>
    <Select v-model="status">
      <SelectTrigger class="w-40" :aria-label="$t('pos.invoices.status')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in DOC_STATUSES" :key="item" :value="item">{{ $t(`inventory.documents.status.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FILTER_ALL } from "@/lib/listing";
import { DOC_STATUSES, DOC_TYPES } from "@/repositories/inventory";

const search = defineModel<string>("search", { required: true });
const docType = defineModel<string>("docType", { required: true });
const status = defineModel<string>("status", { required: true });
</script>
