<template>
  <div class="space-y-2">
    <div class="aspect-square overflow-hidden rounded-md bg-muted/30">
      <img v-if="current" :src="current" alt="" class="size-full object-contain" />
      <div v-else class="grid size-full place-content-center">
        <ImageIcon class="size-16 text-muted-foreground" />
      </div>
    </div>
    <div v-if="images.length > 1" class="flex gap-2 overflow-x-auto pb-1">
      <button
        v-for="url in images"
        :key="url"
        type="button"
        class="size-14 shrink-0 overflow-hidden rounded-md border-2 bg-muted/30"
        :class="url === current ? 'border-primary' : 'border-transparent'"
        @click="picked = url"
      >
        <img :src="url" alt="" class="size-full object-cover" />
      </button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Image as ImageIcon } from "lucide-vue-next";

/**
 * A big picture with a strip of the group's other pictures. `preferred` is the picture to start
 * on (the chosen variant's own); picking a thumbnail overrides it until `preferred` changes again.
 */
const props = defineProps<{ images: string[]; preferred?: string | null }>();

const picked = ref<string | null>(null);
watch(
  () => props.preferred,
  () => {
    picked.value = null;
  }
);

const current = computed(() => picked.value ?? props.preferred ?? props.images[0] ?? null);
</script>
