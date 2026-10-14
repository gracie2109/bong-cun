<template>
  <div class="space-y-3">
    <!-- The fields edit the live filters (the list is filtered in the browser), so Search only closes the popover. -->
    <SearchView
      v-model:search="search"
      :placeholder="$t('rbac.permissions.searchPlaceholder')"
      :active-count="activeCount"
      :refreshing="refreshing"
      @reset-filters="emit('reset')"
      @clear="emit('reset')"
      @refresh="emit('refresh')"
    >
      <template #filters>
        <FilterField :label="$t('rbac.permissions.filterModule')">
          <Select v-model="moduleFilter">
            <SelectTrigger :aria-label="$t('rbac.permissions.filterModule')"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem :value="FILTER_ALL">{{ $t("rbac.permissions.allModules", { n: modules.length }) }}</SelectItem>
              <SelectItem v-for="item in modules" :key="item" :value="item">{{ item }}</SelectItem>
              <SelectItem :value="UNGROUPED">{{ $t("rbac.ungrouped") }}</SelectItem>
            </SelectContent>
          </Select>
        </FilterField>
        <FilterField :label="$t('rbac.permissions.filterMethod')">
          <Select v-model="methodFilter">
            <SelectTrigger :aria-label="$t('rbac.permissions.filterMethod')"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem :value="FILTER_ALL">{{ $t("rbac.permissions.allMethods") }}</SelectItem>
              <SelectItem v-for="method in METHODS" :key="method" :value="method">{{ $t(`rbac.methods.${method}`) }}</SelectItem>
            </SelectContent>
          </Select>
        </FilterField>
      </template>
    </SearchView>
    <div class="space-y-3 rounded-xl border bg-white p-4">
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
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Check } from "lucide-vue-next";
import { FilterField, SearchView } from "@/components/common/search-view";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { METHODS } from "../rbac";
import { UNGROUPED } from "./usePermissionsFilter";
import { FILTER_ALL } from "@/lib/listing";

defineProps<{
  refreshing?: boolean;
  modules: string[];
  topModules: string[];
  unusedCount: number;
  /** Permissions matching the filters, out of `total`. */
  matched: number;
  total: number;
}>();

const emit = defineEmits<{ reset: []; refresh: [] }>();

const search = defineModel<string>("search", { required: true });
const moduleFilter = defineModel<string>("moduleFilter", { required: true });
const methodFilter = defineModel<string>("methodFilter", { required: true });
const onlyUnused = defineModel<boolean>("onlyUnused", { required: true });

const activeCount = computed(
  () => [moduleFilter.value !== FILTER_ALL, methodFilter.value !== FILTER_ALL, onlyUnused.value].filter(Boolean).length
);
</script>
