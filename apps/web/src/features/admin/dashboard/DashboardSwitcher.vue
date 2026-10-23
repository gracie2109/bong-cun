<template>
  <nav v-if="items.length > 1" class="flex gap-1 rounded-lg border bg-white p-0.5" :aria-label="$t('dashboard.switcher')">
    <button
      v-for="item in items"
      :key="item.key"
      type="button"
      class="rounded-md px-3 py-1.5 text-sm font-semibold transition-colors"
      :class="item.key === activeKey ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
      :aria-current="item.key === activeKey ? 'page' : undefined"
      @click="emit('select', item.key)"
    >
      {{ $t(item.titleKey) }}
    </button>
  </nav>
</template>

<script lang="ts" setup>
import type { DashboardDef } from "./kit/types";

defineProps<{ items: readonly DashboardDef[]; activeKey: string | undefined }>();
const emit = defineEmits<{ select: [key: string] }>();
</script>
