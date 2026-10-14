<template>
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
</template>

<script lang="ts" setup>
import type { ItemKind } from "@/repositories/reports";

const kind = defineModel<ItemKind>({ required: true });

const KINDS: ItemKind[] = ["all", "product", "service"];
</script>
