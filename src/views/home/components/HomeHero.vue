<template>
  <section class="relative overflow-hidden">
    <div class="shop-container grid items-center gap-10 py-10 md:py-14 lg:grid-cols-[1.05fr_1fr] lg:gap-14 lg:py-20">
      <div class="max-w-xl">
        <p
          class="shop-reveal inline-flex items-center gap-2 rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-foreground shadow-card"
          :style="{ '--i': 0 }"
        >
          <span class="size-2 rounded-full bg-sage" aria-hidden="true" />{{ $t("client.home.hero.badge") }}
        </p>
        <h1 class="shop-display shop-reveal mt-5 text-[40px] leading-[1.05] sm:text-5xl lg:text-[56px]" :style="{ '--i': 1 }">
          {{ $t("client.home.hero.titleStart") }}
          <span class="relative inline-block text-primary">
            {{ $t("client.home.hero.titleAccent") }}
            <svg class="absolute -bottom-2 left-0 h-3 w-full text-brand/60" viewBox="0 0 200 12" preserveAspectRatio="none" aria-hidden="true">
              <path d="M2 9c40-6 90-8 196-3" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" />
            </svg>
          </span>
        </h1>
        <p class="shop-reveal mt-6 text-lg leading-relaxed text-muted-foreground" :style="{ '--i': 2 }">{{ $t("client.home.hero.text") }}</p>
        <div class="shop-reveal mt-8 flex flex-col gap-3 sm:flex-row" :style="{ '--i': 3 }">
          <Button as-child class="h-[52px] rounded-full px-7 text-base">
            <RouterLink :to="{ name: 'products' }"><ShoppingBasket class="mr-2 size-5" />{{ $t("client.home.hero.shop") }}</RouterLink>
          </Button>
          <Button
            as-child
            variant="outline"
            class="h-[52px] rounded-full border-foreground/20 bg-white px-7 text-base hover:border-foreground hover:bg-white"
          >
            <RouterLink :to="{ name: 'spa' }"><Scissors class="mr-2 size-5" />{{ $t("client.home.hero.spa") }}</RouterLink>
          </Button>
        </div>
        <ul class="shop-reveal mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm text-foreground/80" :style="{ '--i': 4 }">
          <li v-for="key in POINTS" :key="key" class="flex items-center gap-2">
            <Check class="size-4 text-sage" :stroke-width="3" />{{ $t(`client.home.hero.${key}`) }}
          </li>
        </ul>
      </div>

      <HeroPhotos class="shop-reveal" :style="{ '--i': 2 }" />
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Check, Scissors, ShoppingBasket } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import HeroPhotos from "./HeroPhotos.vue";

const POINTS = ["point1", "point2", "point3"] as const;
</script>
