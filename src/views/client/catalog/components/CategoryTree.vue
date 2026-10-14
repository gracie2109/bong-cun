<template>
  <div class="space-y-1">
    <button
      type="button"
      class="w-full rounded-md px-2 py-1.5 text-left text-sm hover:bg-muted"
      :class="{ 'bg-primary/10 font-semibold text-primary': !selected }"
      @click="emit('select', null)"
    >
      {{ $t("client.catalog.allCategories") }}
    </button>
    <div v-for="root in tree" :key="root.id">
      <button
        type="button"
        class="w-full rounded-md px-2 py-1.5 text-left text-sm font-semibold hover:bg-muted"
        :class="{ 'bg-primary/10 text-primary': selected === root.id }"
        @click="emit('select', root.id)"
      >
        {{ root.name }}
      </button>
      <ul v-if="root.children.length > 0" class="ml-3 border-l pl-2">
        <li v-for="child in root.children" :key="child.id">
          <button
            type="button"
            class="w-full rounded-md px-2 py-1 text-left text-sm hover:bg-muted"
            :class="{ 'bg-primary/10 font-semibold text-primary': selected === child.id }"
            @click="emit('select', child.id)"
          >
            {{ child.name }}
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>

<script lang="ts" setup>
import type { CategoryNode } from "@/types/catalog";

defineProps<{ tree: CategoryNode[]; selected: string | null }>();
const emit = defineEmits<{ select: [id: string | null] }>();
</script>
