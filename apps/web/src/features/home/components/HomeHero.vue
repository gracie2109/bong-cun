<template>
  <section class="shop-container pb-12 pt-6 md:pt-8 lg:pb-16">
    <div class="grid gap-8 lg:grid-cols-12 lg:items-stretch lg:gap-12">
      <div class="flex flex-col justify-center lg:col-span-5 lg:py-10">
        <p class="shop-reveal inline-flex w-fit items-center gap-2 text-sm font-semibold text-sage" :style="{ '--i': 0 }">
          <span class="size-2 rounded-full bg-sage" aria-hidden="true" />{{ $t("client.home.hero.badge") }}
        </p>
        <h1 class="shop-display shop-reveal mt-4 text-[40px] leading-[1.04] sm:text-[52px] xl:text-[64px]" :style="{ '--i': 1 }">
          {{ $t("client.home.hero.titleStart") }}
          <span class="text-primary">{{ $t("client.home.hero.titleAccent") }}</span>
        </h1>
        <p class="shop-reveal mt-5 max-w-[34rem] text-lg leading-relaxed text-muted-foreground" :style="{ '--i': 2 }">
          {{ $t("client.home.hero.text") }}
        </p>
        <div class="shop-reveal mt-8 flex flex-col gap-3 sm:flex-row" :style="{ '--i': 3 }">
          <Button as-child class="h-[52px] rounded-full px-7 text-base font-semibold">
            <RouterLink :to="{ name: 'products' }">{{ $t("client.home.hero.shop") }}<ArrowRight class="ml-2 size-5" /></RouterLink>
          </Button>
          <Button as-child variant="outline" class="h-[52px] rounded-full border-foreground/20 bg-transparent px-7 text-base font-semibold hover:bg-white">
            <RouterLink :to="{ name: 'spa' }"><Scissors class="mr-2 size-5" />{{ $t("client.home.hero.spa") }}</RouterLink>
          </Button>
        </div>
      </div>

      <div class="shop-reveal relative lg:col-span-7" :style="{ '--i': 2 }">
        <ShopImage
          :src="SHOP_PHOTOS.hero.src"
          :alt="$t(SHOP_PHOTOS.hero.alt)"
          :width="1100"
          sizes="(min-width: 1024px) 58vw, 100vw"
          eager
          class="aspect-[4/3] rounded-[28px] lg:aspect-auto lg:h-full lg:min-h-[540px] xl:min-h-[600px]"
        />
        <div class="absolute bottom-4 left-4 right-4 flex flex-wrap items-center gap-x-4 gap-y-1 rounded-2xl bg-white/95 px-4 py-3 text-sm shadow-card backdrop-blur sm:right-auto">
          <span class="inline-flex items-center gap-2 font-semibold"><Clock class="size-4 text-sage" />{{ STORE_INFO.hours }}</span>
          <span class="inline-flex items-center gap-2 text-muted-foreground"><MapPin class="size-4 text-sage" />{{ STORE_INFO.address }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { ArrowRight, Clock, MapPin, Scissors } from "lucide-vue-next";
import ShopImage from "@/components/shop/ShopImage.vue";
import { Button } from "@/components/ui/button";
import { SHOP_PHOTOS } from "@/config/shopImagery";
import { STORE_INFO } from "@/config/storeInfo";
</script>
