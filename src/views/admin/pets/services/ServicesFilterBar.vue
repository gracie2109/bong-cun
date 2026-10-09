<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('petCare.services.searchPlaceholder')" />
    </div>
    <Select v-model="speciesFilter">
      <SelectTrigger class="w-40" :aria-label="$t('petCare.services.filterSpecies')">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem v-for="item in species" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
      </SelectContent>
    </Select>
    <Select v-model="typeFilter">
      <SelectTrigger class="w-48" :aria-label="$t('petCare.services.filterType')">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
        <SelectItem value="by_weight">{{ $t("petCare.services.typeByWeight") }}</SelectItem>
        <SelectItem value="all">{{ $t("petCare.services.typeAll") }}</SelectItem>
      </SelectContent>
    </Select>
    <label class="flex items-center gap-2 text-sm text-muted-foreground">
      <Switch v-model="showArchived" />
      {{ $t("petCare.services.showArchived") }}
    </label>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { FILTER_ALL } from "@/lib/listing";

defineProps<{ species: { id: string; name: string }[] }>();

const search = defineModel<string>("search", { required: true });
const speciesFilter = defineModel<string>("speciesFilter", { required: true });
const typeFilter = defineModel<string>("typeFilter", { required: true });
const showArchived = defineModel<boolean>("showArchived", { required: true });
</script>
