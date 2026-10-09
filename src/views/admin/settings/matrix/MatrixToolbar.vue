<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
      <div class="relative min-w-52 flex-1">
        <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input v-model="search" class="pl-9" :placeholder="$t('rbac.matrix.searchPlaceholder')" />
      </div>
      <label
        v-if="canManage"
        class="flex cursor-pointer items-center gap-2 rounded-lg border px-3 py-1.5"
        :class="quickEdit ? 'border-primary bg-primary/5' : ''"
      >
        <Checkbox v-model:checked="quickEdit" />
        <span class="leading-tight">
          <span class="block text-sm font-semibold">{{ $t("rbac.matrix.quickEdit") }}</span>
          <span class="block text-[11px] text-muted-foreground">{{ $t("rbac.matrix.quickEditHint") }}</span>
        </span>
      </label>
      <span class="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
        <span class="size-2 rounded-full bg-primary" />
        {{ $t("rbac.matrix.permissionCount", { n: permissionCount }) }}
      </span>
    </div>

    <div class="flex flex-wrap gap-2">
      <button
        v-for="chip in chips"
        :key="chip.key"
        type="button"
        class="rounded-full border px-3 py-1.5 text-sm font-medium transition-colors"
        :class="moduleFilter === chip.key ? 'border-foreground bg-foreground text-background' : 'bg-white hover:bg-muted'"
        @click="moduleFilter = chip.key"
      >
        {{ chip.label }} ({{ chip.count }})
      </button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";

defineProps<{
  canManage: boolean;
  permissionCount: number;
  chips: { key: string; label: string; count: number }[];
}>();

const search = defineModel<string>("search", { required: true });
const quickEdit = defineModel<boolean>("quickEdit", { required: true });
const moduleFilter = defineModel<string>("moduleFilter", { required: true });
</script>
