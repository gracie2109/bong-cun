<template>
  <div class="space-y-3 rounded-xl border bg-white p-4">
    <div class="flex flex-wrap items-center gap-3">
      <div class="relative min-w-[200px] flex-1">
        <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input v-model="search" class="pl-9" :placeholder="$t('client.catalog.searchPlaceholder')" />
      </div>
      <Button variant="outline" class="lg:hidden" @click="emit('openFilters')">
        <SlidersHorizontal class="mr-2 size-4" />{{ $t("client.catalog.filters") }}
      </Button>
      <CatalogSort :model-value="sort" @update:model-value="emit('sort', $event)" />
    </div>
    <div class="flex flex-wrap items-center justify-between gap-2 text-sm">
      <div class="flex flex-wrap items-center gap-2">
        <button v-for="chip in chips" :key="chip.key" type="button" class="flex items-center gap-1 rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary" @click="chip.remove()">
          {{ chip.label }}<X class="size-3" />
        </button>
      </div>
      <p class="text-muted-foreground">{{ $t("client.catalog.found", { count: total }) }}</p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Search, SlidersHorizontal, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { CatalogSort as Sort, FilterChip } from "@/types/catalog";
import CatalogSort from "./CatalogSort.vue";

defineProps<{ sort: Sort; total: number; chips: FilterChip[] }>();
const search = defineModel<string>("search", { required: true });
const emit = defineEmits<{ sort: [value: Sort]; openFilters: [] }>();
</script>
