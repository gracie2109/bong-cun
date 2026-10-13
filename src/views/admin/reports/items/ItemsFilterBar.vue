<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="flex gap-1 rounded-lg border p-0.5">
      <button
        v-for="item in KINDS"
        :key="item"
        type="button"
        class="rounded-md px-3 py-1 text-xs font-semibold transition-colors"
        :class="kind === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
        @click="kind = item"
      >
        {{ $t(`reports.kinds.${item}`) }}
      </button>
    </div>
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('reports.items.searchPlaceholder')" />
    </div>
    <Select v-model="sort">
      <SelectTrigger class="w-48" :aria-label="$t('reports.items.sort')"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem v-for="item in SORTS" :key="item" :value="item">{{ $t(`reports.sorts.${item}`) }}</SelectItem>
      </SelectContent>
    </Select>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { ItemKind, ItemSort } from "@/repositories/reports";

const search = defineModel<string>("search", { required: true });
const kind = defineModel<ItemKind>("kind", { required: true });
const sort = defineModel<ItemSort>("sort", { required: true });

const KINDS: ItemKind[] = ["all", "product", "service"];
const SORTS: ItemSort[] = ["revenue", "qty", "profit"];
</script>
