<template>
  <ul class="space-y-1">
    <li v-for="brand in brands" :key="brand.id">
      <label class="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-muted">
        <input
          type="checkbox"
          class="size-4 accent-primary"
          :checked="selected === brand.id"
          @change="emit('select', selected === brand.id ? null : brand.id)"
        />
        <span class="truncate">{{ brand.name }}</span>
      </label>
    </li>
  </ul>
</template>

<script lang="ts" setup>
defineProps<{ brands: { id: string; name: string }[]; selected: string | null }>();
const emit = defineEmits<{ select: [id: string | null] }>();
</script>
