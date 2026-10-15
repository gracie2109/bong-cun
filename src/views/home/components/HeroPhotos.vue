<template>
  <div class="relative mx-auto w-full max-w-[520px] pb-8 pl-8 sm:pb-10 sm:pl-12">
    <span class="absolute -right-6 -top-6 size-48 rounded-full bg-brand/15 blur-2xl sm:size-64" aria-hidden="true" />
    <ShopImage
      :src="SHOP_PHOTOS.hero.src"
      :alt="$t(SHOP_PHOTOS.hero.alt)"
      :width="720"
      sizes="(min-width: 1024px) 520px, 90vw"
      eager
      class="aspect-[4/5] rounded-[32px] shadow-lift"
    />
    <ShopImage
      :src="SHOP_PHOTOS.heroSide.src"
      :alt="$t(SHOP_PHOTOS.heroSide.alt)"
      :width="320"
      sizes="200px"
      class="absolute bottom-0 left-0 aspect-square w-[38%] rounded-3xl border-[6px] border-background shadow-lift"
    />
    <RouterLink
      :to="{ name: 'spa' }"
      class="hero-float absolute right-3 top-6 flex items-center gap-3 rounded-2xl bg-white/95 py-2.5 pl-2.5 pr-4 shadow-lift backdrop-blur sm:-right-4 sm:top-10"
    >
      <span class="grid size-10 place-content-center rounded-xl bg-sage-soft text-sage"><CalendarCheck class="size-5" /></span>
      <span class="leading-tight">
        <span class="block text-sm font-semibold">{{ $t("client.home.hero.cardTitle") }}</span>
        <span class="block text-xs text-muted-foreground">{{ $t("client.home.hero.cardText") }}</span>
      </span>
    </RouterLink>
  </div>
</template>

<script lang="ts" setup>
import { CalendarCheck } from "lucide-vue-next";
import ShopImage from "@/components/shop/ShopImage.vue";
import { SHOP_PHOTOS } from "@/config/shopImagery";
</script>

<style scoped>
.hero-float {
  animation: hero-float 4s var(--ease-in-out) infinite alternate;
}
@keyframes hero-float {
  to {
    transform: translateY(-8px);
  }
}
</style>
