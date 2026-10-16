<template>
  <section class="bg-sage-soft">
    <div class="shop-container grid items-center gap-8 py-10 md:py-14 lg:grid-cols-[1.1fr_1fr] lg:gap-14">
      <div>
        <p class="shop-eyebrow !text-sage">{{ $t("client.spa.eyebrow") }}</p>
        <h1 class="shop-display mt-2 text-[34px] leading-[1.1] md:text-5xl">{{ $t("client.spa.title") }}</h1>
        <p class="mt-4 max-w-xl text-lg text-muted-foreground">{{ $t("client.spa.intro") }}</p>
        <div class="mt-7 flex flex-col gap-3 sm:flex-row">
          <Button as-child class="h-12 rounded-full bg-sage px-6 text-base hover:bg-sage/90">
            <RouterLink :to="bookTarget"><CalendarPlus class="mr-2 size-5" />{{ bookLabel }}</RouterLink>
          </Button>
          <Button as-child variant="outline" class="h-12 rounded-full border-sage/30 bg-transparent px-6 text-base hover:bg-white">
            <a :href="`tel:${STORE_INFO.phone}`"><Phone class="mr-2 size-4" />{{ STORE_INFO.phone }}</a>
          </Button>
        </div>
      </div>
      <ShopImage
        :src="SHOP_PHOTOS.spa.src"
        :alt="$t(SHOP_PHOTOS.spa.alt)"
        :width="720"
        sizes="(min-width: 1024px) 560px, 100vw"
        eager
        class="hidden aspect-[5/4] rounded-[32px] shadow-lift sm:block"
      />
    </div>
  </section>
</template>

<script lang="ts" setup>
import { CalendarPlus, Phone } from "lucide-vue-next";
import type { RouteLocationRaw } from "vue-router";
import ShopImage from "@/components/shop/ShopImage.vue";
import { Button } from "@/components/ui/button";
import { SHOP_PHOTOS } from "@/config/shopImagery";
import { STORE_INFO } from "@/config/storeInfo";

defineProps<{ bookTarget: RouteLocationRaw; bookLabel: string }>();
</script>
