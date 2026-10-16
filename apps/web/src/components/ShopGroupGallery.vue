<template>
  <div class="space-y-3">
    <div class="relative aspect-square overflow-hidden rounded-3xl bg-white ring-1 ring-border/70">
      <Transition name="gallery" mode="out-in">
        <img
          v-if="current"
          :key="current"
          :src="current"
          :alt="alt"
          class="size-full object-contain p-[7%]"
          fetchpriority="high"
        />
        <div v-else class="grid size-full place-content-center bg-muted text-muted-foreground/40"><PawMark class="size-20" /></div>
      </Transition>
      <template v-if="images.length > 1">
        <button
          v-for="dir in [-1, 1] as const"
          :key="dir"
          type="button"
          class="absolute top-1/2 grid size-10 -translate-y-1/2 place-content-center rounded-full bg-white/90 shadow-card transition-transform hover:scale-105"
          :class="dir < 0 ? 'left-3' : 'right-3'"
          :aria-label="$t(dir < 0 ? 'client.product.prevImage' : 'client.product.nextImage')"
          @click="step(dir)"
        >
          <component :is="dir < 0 ? ChevronLeft : ChevronRight" class="size-5" />
        </button>
        <span class="absolute bottom-3 left-1/2 -translate-x-1/2 rounded-full bg-foreground/70 px-2.5 py-0.5 text-xs font-medium tabular-nums text-white">
          {{ index + 1 }} / {{ images.length }}
        </span>
      </template>
    </div>
    <div v-if="images.length > 1" class="shop-scroll-row">
      <button
        v-for="(url, i) in images"
        :key="url"
        type="button"
        class="size-16 shrink-0 overflow-hidden rounded-xl bg-white ring-1 transition-[box-shadow,opacity] sm:size-20"
        :class="url === current ? 'ring-2 ring-primary' : 'opacity-70 ring-border hover:opacity-100'"
        :aria-label="$t('client.product.imageN', { n: i + 1 })"
        :aria-current="url === current"
        @click="picked = url"
      >
        <img :src="url" alt="" loading="lazy" class="size-full object-contain p-1.5" />
      </button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import PawMark from "@/components/shop/PawMark.vue";

/**
 * A big picture with a strip of the group's other pictures. `preferred` is the picture to start
 * on (the chosen variant's own); picking a thumbnail overrides it until `preferred` changes again.
 */
const props = withDefaults(defineProps<{ images: string[]; preferred?: string | null; alt?: string }>(), {
  preferred: null,
  alt: "",
});

const picked = ref<string | null>(null);
watch(
  () => props.preferred,
  () => {
    picked.value = null;
  }
);

const current = computed(() => picked.value ?? props.preferred ?? props.images[0] ?? null);
const index = computed(() => Math.max(0, props.images.indexOf(current.value ?? "")));
const step = (dir: -1 | 1) => {
  const count = props.images.length;
  picked.value = props.images[(index.value + dir + count) % count] ?? null;
};
</script>

<style scoped>
.gallery-enter-active,
.gallery-leave-active {
  transition: opacity 220ms var(--ease-out), transform 220ms var(--ease-out);
}
.gallery-enter-from,
.gallery-leave-to {
  opacity: 0;
  transform: scale(0.985);
}
</style>
