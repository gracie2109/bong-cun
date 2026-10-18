<template>
  <RouterLink :to="{ name: 'home' }" class="group inline-flex shrink-0 items-center gap-2.5" :aria-label="STORE_INFO.name">
    <img
      src="/icons/logo-mark.png"
      alt=""
      width="40"
      height="40"
      class="size-10 rounded-full ring-2 ring-white/70 transition-transform duration-300 ease-pop group-hover:-rotate-12"
    />
    <span class="leading-none">
      <span class="block text-lg font-extrabold tracking-tight" :class="inverted ? 'text-white' : 'text-foreground'">{{ STORE_INFO.brand }}</span>
      <span class="mt-1 block text-[11px] font-medium" :class="inverted ? 'text-white/60' : 'text-muted-foreground'">
        {{ $t("client.brand.tagline") }}
      </span>
    </span>
  </RouterLink>
</template>

<script setup lang="ts">
import { STORE_INFO } from "@/config/storeInfo";

defineProps<{ inverted?: boolean }>();
</script>
