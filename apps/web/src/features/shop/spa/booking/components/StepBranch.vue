<template>
  <div class="grid gap-3 sm:grid-cols-2">
    <button
      v-for="branch in branches"
      :key="branch.id"
      type="button"
      class="rounded-2xl border-2 bg-white p-4 text-left transition-colors duration-200"
      :class="branch.id === selected ? 'border-sage bg-sage-soft' : 'border-border hover:border-foreground/30'"
      :aria-pressed="branch.id === selected"
      @click="emit('pick', branch.id)"
    >
      <span class="block font-semibold">{{ branch.name }}</span>
      <span v-if="branch.address" class="mt-1 block text-sm text-muted-foreground">{{ branch.address }}</span>
      <span v-if="branch.phone" class="block text-sm text-muted-foreground">{{ branch.phone }}</span>
    </button>
  </div>
</template>

<script lang="ts" setup>
import type { Branch } from "@bongcun/supabase/users";

defineProps<{ branches: Branch[]; selected: string | null }>();
const emit = defineEmits<{ pick: [id: string] }>();
</script>
