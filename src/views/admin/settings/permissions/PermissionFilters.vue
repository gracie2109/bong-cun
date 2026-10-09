<template>
  <div class="space-y-3 rounded-xl border bg-white p-4">
    <div class="flex flex-wrap items-center gap-3">
      <div class="relative min-w-60 flex-1">
        <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input v-model="search" class="pl-9" :placeholder="$t('rbac.permissions.searchPlaceholder')" />
      </div>
      <Select v-model="moduleFilter">
        <SelectTrigger class="w-52" :aria-label="$t('rbac.permissions.filterModule')">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem :value="FILTER_ALL">{{ $t("rbac.permissions.allModules", { n: modules.length }) }}</SelectItem>
          <SelectItem v-for="item in modules" :key="item" :value="item">{{ item }}</SelectItem>
          <SelectItem :value="UNGROUPED">{{ $t("rbac.ungrouped") }}</SelectItem>
        </SelectContent>
      </Select>
      <Select v-model="methodFilter">
        <SelectTrigger class="w-44" :aria-label="$t('rbac.permissions.filterMethod')">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem :value="FILTER_ALL">{{ $t("rbac.permissions.allMethods") }}</SelectItem>
          <SelectItem v-for="method in METHODS" :key="method" :value="method">{{ $t(`rbac.methods.${method}`) }}</SelectItem>
        </SelectContent>
      </Select>
      <Button variant="outline" size="icon" :aria-label="$t('rbac.permissions.resetFilters')" @click="emit('reset')">
        <RotateCcw class="size-4" />
      </Button>
    </div>
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span class="font-bold uppercase tracking-wider text-muted-foreground">{{ $t("rbac.permissions.quickFilters") }}</span>
        <button
          type="button"
          class="flex items-center gap-1.5 rounded-full border px-3 py-1 font-medium transition-colors"
          :class="onlyUnused ? 'border-amber-300 bg-amber-50 text-amber-700' : 'hover:bg-muted'"
          @click="onlyUnused = !onlyUnused"
        >
          <span class="size-1.5 rounded-full bg-amber-500" />
          {{ $t("rbac.permissions.unusedChip", { n: unusedCount }) }}
          <Check v-if="onlyUnused" class="size-3" />
        </button>
        <button
          v-for="item in topModules"
          :key="item"
          type="button"
          class="rounded-full border px-3 py-1 font-medium transition-colors"
          :class="moduleFilter === item ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
          @click="moduleFilter = moduleFilter === item ? FILTER_ALL : item"
        >
          {{ item }}
        </button>
      </div>
      <p class="text-xs text-muted-foreground">
        {{ $t("rbac.permissions.resultCount") }}
        <b class="text-foreground">{{ $t("rbac.permissions.ratio", { n: matched, total }) }}</b>
      </p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Check, RotateCcw, Search } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { METHODS } from "../rbac";
import { UNGROUPED } from "./usePermissionsFilter";
import { FILTER_ALL } from "@/lib/listing";

defineProps<{
  modules: string[];
  topModules: string[];
  unusedCount: number;
  /** Permissions matching the filters, out of `total`. */
  matched: number;
  total: number;
}>();

const emit = defineEmits<{ reset: [] }>();

const search = defineModel<string>("search", { required: true });
const moduleFilter = defineModel<string>("moduleFilter", { required: true });
const methodFilter = defineModel<string>("methodFilter", { required: true });
const onlyUnused = defineModel<boolean>("onlyUnused", { required: true });
</script>
