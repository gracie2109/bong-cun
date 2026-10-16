<template>
  <div class="mx-auto flex max-w-md flex-col items-center px-4 py-14 text-center" :role="tone === 'error' ? 'alert' : 'status'">
    <div class="relative mb-6">
      <span class="absolute inset-0 -z-10 scale-125 rounded-full blur-2xl" :class="tone === 'error' ? 'bg-destructive/10' : 'bg-brand/15'" />
      <span
        class="empty-float grid size-24 place-content-center rounded-full"
        :class="tone === 'error' ? 'bg-destructive/10 text-destructive' : 'bg-brand-soft text-brand'"
      >
        <slot name="icon"><PawMark class="size-12" /></slot>
      </span>
    </div>
    <h2 class="text-xl font-bold tracking-tight">{{ title }}</h2>
    <p v-if="text" class="mt-2 text-muted-foreground">{{ text }}</p>
    <div v-if="$slots.default" class="mt-6 flex flex-wrap justify-center gap-3"><slot /></div>
  </div>
</template>

<script lang="ts" setup>
import PawMark from "./PawMark.vue";

/** The shop's empty, not-found and error message: an icon, a title, a line of help and the actions in the slot. */
withDefaults(defineProps<{ title: string; text?: string; tone?: "empty" | "error" }>(), { text: "", tone: "empty" });
</script>

<style scoped>
.empty-float {
  animation: empty-float 3.2s var(--ease-in-out) infinite alternate;
}
@keyframes empty-float {
  to {
    transform: translateY(-6px);
  }
}
</style>
