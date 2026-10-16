<template>
  <div class="relative overflow-hidden bg-brand-soft">
    <img
      v-if="!failed"
      ref="img"
      :src="sizedPhoto(src, width)"
      :srcset="srcset"
      :sizes="sizes"
      :alt="alt"
      :loading="eager ? 'eager' : 'lazy'"
      :fetchpriority="eager ? 'high' : undefined"
      decoding="async"
      class="size-full object-cover transition-opacity duration-500"
      :class="loaded ? 'opacity-100' : 'opacity-0'"
      @load="loaded = true"
      @error="failed = true"
    />
    <div v-if="failed || !loaded" class="absolute inset-0 grid place-content-center text-brand/40" aria-hidden="true">
      <PawMark class="size-16" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref, useTemplateRef } from "vue";
import { sizedPhoto } from "@/config/shopImagery";
import PawMark from "./PawMark.vue";

/** A marketing photo that fades in, and falls back to a paw tile when the link is broken. */
const props = withDefaults(defineProps<{ src: string; alt: string; width?: number; sizes?: string; eager?: boolean }>(), {
  width: 900,
  sizes: "100vw",
  eager: false,
});

const loaded = ref(false);
const failed = ref(false);
const img = useTemplateRef<HTMLImageElement>("img");

// A server-rendered image can finish loading before hydration, when its load event has already gone.
onMounted(() => {
  if (!img.value?.complete) return;
  if (img.value.naturalWidth > 0) loaded.value = true;
  else failed.value = true;
});
const srcset = computed(() => [0.5, 1, 1.6].map((k) => `${sizedPhoto(props.src, Math.round(props.width * k))} ${Math.round(props.width * k)}w`).join(", "));
</script>
