<template>
  <RouterLink :to="{ name: 'home' }" class="group inline-flex shrink-0 items-center gap-2.5" :aria-label="STORE_INFO.name">
    <span
      class="grid size-10 place-content-center rounded-full bg-brand text-white transition-transform duration-300 ease-pop group-hover:-rotate-12"
    >
      <PawMark class="size-6" />
    </span>
    <span class="leading-none">
      <span class="block text-lg font-extrabold tracking-tight" :class="inverted ? 'text-white' : 'text-foreground'">Bông Cún</span>
      <span class="mt-1 block text-[11px] font-medium" :class="inverted ? 'text-white/60' : 'text-muted-foreground'">
        {{ $t("client.brand.tagline") }}
      </span>
    </span>
  </RouterLink>
</template>

<script setup lang="ts">
import PawMark from "@/components/shop/PawMark.vue";
import { STORE_INFO } from "@/config/storeInfo";

defineProps<{ inverted?: boolean }>();
</script>
