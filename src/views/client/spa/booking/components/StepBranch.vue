<template>
  <div class="grid gap-3 sm:grid-cols-2">
    <button
      v-for="branch in branches"
      :key="branch.id"
      type="button"
      class="rounded-xl border bg-white p-4 text-left transition-colors hover:bg-muted/40"
      :class="branch.id === selected && 'border-primary bg-primary/5'"
      @click="emit('pick', branch.id)"
    >
      <span class="block font-semibold">{{ branch.name }}</span>
      <span v-if="branch.address" class="mt-1 block text-sm text-muted-foreground">{{ branch.address }}</span>
      <span v-if="branch.phone" class="block text-sm text-muted-foreground">{{ branch.phone }}</span>
    </button>
  </div>
</template>

<script lang="ts" setup>
import type { Branch } from "@/repositories/branches";

defineProps<{ branches: Branch[]; selected: string | null }>();
const emit = defineEmits<{ pick: [id: string] }>();
</script>
