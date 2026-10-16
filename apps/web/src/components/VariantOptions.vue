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
          class="border text-sm transition-colors"
          :class="[
            pill ? 'min-h-10 rounded-full px-4' : 'min-h-9 rounded-md px-3',
            picks[index] === value
              ? pill
                ? 'border-foreground bg-foreground font-semibold text-white'
                : 'border-primary bg-primary/10 font-semibold text-primary'
              : pill
                ? 'bg-white hover:border-foreground/50'
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
import type { ProductAttribute } from "@bongcun/supabase/products";

defineProps<{
  attributes: ProductAttribute[];
  picks: (string | null)[];
  isAvailable: (index: number, value: string) => boolean;
  /** Round chips, as the public shop draws them; the POS keeps the compact square ones. */
  pill?: boolean;
}>();
const emit = defineEmits<{ pick: [index: number, value: string] }>();
</script>
