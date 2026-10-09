<template>
  <div ref="el" class="h-px w-full" aria-hidden="true" />
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { useIntersectionObserver } from "@vueuse/core";

/** An invisible marker at the end of a scrolling list: `visible` fires when the list is scrolled down to it. */
const emit = defineEmits<{ visible: [] }>();

const el = ref<HTMLElement | null>(null);

useIntersectionObserver(el, ([entry]) => {
  if (entry?.isIntersecting) emit("visible");
});
</script>
