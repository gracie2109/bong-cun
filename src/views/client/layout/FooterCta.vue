<template>
  <div class="border-b border-white/10">
    <div class="shop-container flex flex-col gap-5 py-10 md:flex-row md:items-center md:justify-between">
      <div class="flex items-center gap-4">
        <span class="grid size-12 shrink-0 place-content-center rounded-full bg-brand text-white">
          <PawMark class="size-7" />
        </span>
        <div>
          <p class="text-lg font-bold text-white md:text-xl">{{ $t("client.footer.ctaTitle") }}</p>
          <p class="mt-1 text-white/60">{{ $t("client.footer.ctaText") }}</p>
        </div>
      </div>
      <div class="flex flex-wrap gap-3">
        <RouterLink
          :to="{ name: 'spa' }"
          class="inline-flex h-11 items-center rounded-full bg-white px-5 font-semibold text-foreground transition-transform hover:-translate-y-0.5"
        >
          {{ $t("client.header.bookSpa") }}
        </RouterLink>
        <a
          :href="`tel:${STORE_INFO.phone}`"
          class="inline-flex h-11 items-center gap-2 rounded-full border border-white/25 px-5 font-semibold text-white transition-colors hover:bg-white/10"
        >
          <Phone class="size-4" />{{ STORE_INFO.phone }}
        </a>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Phone } from "lucide-vue-next";
import PawMark from "@/components/shop/PawMark.vue";
import { STORE_INFO } from "@/config/storeInfo";
</script>
