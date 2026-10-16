<template>
  <Select v-if="options.length > 1" :model-value="modelValue" @update:model-value="emit('update:modelValue', String($event))">
    <SelectTrigger class="h-9 w-52" :aria-label="$t('pos.branch')">
      <Store class="mr-2 size-4 text-muted-foreground" />
      <SelectValue />
    </SelectTrigger>
    <SelectContent>
      <SelectItem v-if="canPickAll" :value="ALL_BRANCHES">{{ $t("reports.allBranches") }}</SelectItem>
      <SelectItem v-for="item in options" :key="item.id" :value="item.id">{{ item.code }} · {{ item.name }}</SelectItem>
    </SelectContent>
  </Select>
  <span v-else-if="options.length" class="flex items-center gap-2 rounded-lg border bg-white px-3 py-1.5 text-sm">
    <Store class="size-4 text-muted-foreground" />
    {{ options[0].code }} · {{ options[0].name }}
  </span>
</template>

<script lang="ts" setup>
import { Store } from "lucide-vue-next";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Branch } from "@bongcun/supabase/users";
import { ALL_BRANCHES } from "./useReportFilters";

defineProps<{ modelValue: string | undefined; options: Branch[]; canPickAll: boolean }>();
const emit = defineEmits<{ "update:modelValue": [value: string] }>();
</script>
