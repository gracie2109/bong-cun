<template>
  <div class="flex flex-wrap gap-2" role="radiogroup" :aria-label="$t('client.catalog.brands')">
    <button
      v-for="brand in brands"
      :key="brand.id"
      type="button"
      role="radio"
      class="h-9 rounded-full border px-3.5 text-[13px] font-medium transition-[background-color,border-color,color] duration-200"
      :class="selected === brand.id ? 'border-foreground bg-foreground text-white' : 'bg-white hover:border-foreground/40'"
      :aria-checked="selected === brand.id"
      @click="emit('select', selected === brand.id ? null : brand.id)"
    >
      {{ brand.name }}
    </button>
  </div>
</template>

<script lang="ts" setup>
defineProps<{ brands: { id: string; name: string }[]; selected: string | null }>();
const emit = defineEmits<{ select: [id: string | null] }>();
</script>
