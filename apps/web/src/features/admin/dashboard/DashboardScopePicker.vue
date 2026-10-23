<template>
  <Select v-if="branches.length > 1" :model-value="value" @update:model-value="emit('select', String($event))">
    <SelectTrigger class="h-9 w-52" :aria-label="$t('pos.branch')">
      <Store class="mr-2 size-4 text-muted-foreground" />
      <SelectValue />
    </SelectTrigger>
    <SelectContent>
      <SelectItem v-if="allowAll" value="all">{{ $t("dashboard.allBranches") }}</SelectItem>
      <SelectItem v-for="item in branches" :key="item.id" :value="item.id">{{ item.code }} · {{ item.name }}</SelectItem>
    </SelectContent>
  </Select>
  <span v-else-if="branches.length" class="flex items-center gap-2 rounded-lg border bg-white px-3 py-1.5 text-sm">
    <Store class="size-4 text-muted-foreground" />
    {{ branches[0].code }} · {{ branches[0].name }}
  </span>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Store } from "lucide-vue-next";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Branch } from "@bongcun/supabase/users";
import type { DashboardScope } from "./kit/types";

const props = defineProps<{ scope: DashboardScope; branches: Branch[]; allowAll: boolean }>();
const emit = defineEmits<{ select: [value: string] }>();

const value = computed(() => (props.scope.kind === "all" ? "all" : props.scope.branchId));
</script>
