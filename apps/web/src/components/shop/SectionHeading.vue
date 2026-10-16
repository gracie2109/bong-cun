<template>
  <div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
    <div class="max-w-2xl">
      <p v-if="eyebrow" class="shop-eyebrow mb-2">{{ eyebrow }}</p>
      <component :is="as" class="shop-display text-2xl md:text-[32px] md:leading-tight">{{ title }}</component>
      <p v-if="text" class="mt-2 text-muted-foreground md:text-lg">{{ text }}</p>
    </div>
    <RouterLink
      v-if="linkTo && linkLabel"
      :to="linkTo"
      class="group inline-flex h-10 items-center gap-1.5 text-sm font-semibold text-primary"
    >
      {{ linkLabel }}<ArrowRight class="size-4 transition-transform duration-200 group-hover:translate-x-1" />
    </RouterLink>
  </div>
</template>

<script lang="ts" setup>
import { ArrowRight } from "lucide-vue-next";
import type { RouteLocationRaw } from "vue-router";

withDefaults(
  defineProps<{ title: string; eyebrow?: string; text?: string; linkTo?: RouteLocationRaw; linkLabel?: string; as?: "h1" | "h2" }>(),
  { eyebrow: "", text: "", linkTo: undefined, linkLabel: "", as: "h2" }
);
</script>
