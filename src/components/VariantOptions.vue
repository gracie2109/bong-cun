<template>
  <div class="space-y-3">
    <div v-for="(attribute, index) in attributes" :key="attribute.id">
      <p class="mb-1.5 text-sm font-medium">
        {{ attribute.name }}<span v-if="picks[index]" class="font-normal text-muted-foreground">: {{ picks[index] }}</span>
      </p>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="value in attribute.values"
          :key="value"
          type="button"
          class="min-h-9 rounded-md border px-3 text-sm transition-colors"
          :class="[
            picks[index] === value
              ? 'border-primary bg-primary/10 font-semibold text-primary'
              : 'hover:border-primary/60',
            isAvailable(index, value) ? '' : 'border-dashed text-muted-foreground line-through decoration-1',
          ]"
          :aria-pressed="picks[index] === value"
          @click="emit('pick', index, value)"
        >
          {{ value }}
        </button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import type { ProductAttribute } from "@/repositories/products";

defineProps<{
  attributes: ProductAttribute[];
  picks: (string | null)[];
  isAvailable: (index: number, value: string) => boolean;
}>();
const emit = defineEmits<{ pick: [index: number, value: string] }>();
</script>
