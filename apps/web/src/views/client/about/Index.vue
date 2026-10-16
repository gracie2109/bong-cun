<template>
  <div class="pb-16">
    <section class="shop-container grid items-center gap-10 pt-8 md:pt-14 lg:grid-cols-[1.1fr_1fr] lg:gap-14">
      <header>
        <p class="shop-eyebrow">{{ $t("client.about.eyebrow") }}</p>
        <h1 class="shop-display mt-2 text-[34px] leading-[1.1] md:text-5xl">{{ $t("client.about.title") }}</h1>
        <p class="mt-5 text-lg leading-relaxed text-muted-foreground">{{ $t("client.about.intro") }}</p>
        <div class="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button as-child class="h-12 rounded-full px-6 text-base">
            <RouterLink :to="{ name: 'products' }">{{ $t("client.about.cta") }}<ArrowRight class="ml-2 size-4" /></RouterLink>
          </Button>
          <Button as-child variant="outline" class="h-12 rounded-full border-foreground/20 bg-white px-6 text-base">
            <RouterLink :to="{ name: 'spa' }">{{ $t("client.home.paths.care.cta") }}</RouterLink>
          </Button>
        </div>
      </header>
      <ShopImage
        :src="SHOP_PHOTOS.visit.src"
        :alt="$t(SHOP_PHOTOS.visit.alt)"
        :width="720"
        sizes="(min-width: 1024px) 560px, 100vw"
        eager
        class="aspect-[4/3] rounded-[32px] shadow-lift"
      />
    </section>

    <section class="shop-container mt-16 md:mt-24">
      <div class="rounded-[32px] bg-foreground p-8 text-white md:p-12">
        <p class="shop-eyebrow !text-brand">{{ $t("client.about.mission") }}</p>
        <p class="shop-display mt-3 max-w-3xl text-2xl leading-snug md:text-[32px]">{{ $t("client.about.missionText") }}</p>
      </div>
      <ul class="mt-6 grid gap-4 md:grid-cols-3">
        <li v-for="(value, index) in VALUES" :key="value.key" class="shop-reveal rounded-3xl border bg-white p-6" :style="{ '--i': index }">
          <span class="grid size-11 place-content-center rounded-2xl bg-sage-soft text-sage"><component :is="value.icon" class="size-5" /></span>
          <p class="mt-4 text-lg font-bold">{{ $t(`client.about.${value.key}`) }}</p>
          <p class="mt-1 text-sm text-muted-foreground">{{ $t(`client.about.${value.key}Text`) }}</p>
        </li>
      </ul>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ArrowRight, HeartHandshake, ShieldCheck, Sparkles } from "lucide-vue-next";
import ShopImage from "@/components/shop/ShopImage.vue";
import { Button } from "@/components/ui/button";
import { SHOP_PHOTOS } from "@/config/shopImagery";

const VALUES = [
  { key: "v1", icon: ShieldCheck },
  { key: "v2", icon: Sparkles },
  { key: "v3", icon: HeartHandshake },
] as const;
</script>
