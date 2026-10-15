<template>
  <section class="shop-container pt-16 md:pt-24">
    <SectionHeading :eyebrow="$t('client.home.paths.eyebrow')" :title="$t('client.home.paths.title')" />
    <div class="mt-8 grid gap-4 md:grid-cols-2 md:gap-6">
      <RouterLink
        v-for="path in paths"
        :key="path.key"
        :to="path.to"
        class="group relative isolate flex min-h-[340px] flex-col justify-end overflow-hidden rounded-[28px] p-6 text-white md:min-h-[420px] md:p-8"
      >
        <ShopImage
          :src="path.photo.src"
          :alt="$t(path.photo.alt)"
          :width="760"
          sizes="(min-width: 768px) 50vw, 100vw"
          class="absolute inset-0 -z-10 transition-transform duration-700 ease-out-quart group-hover:scale-[1.04]"
        />
        <span class="absolute inset-0 -z-10 bg-gradient-to-t from-black/75 via-black/30 to-transparent" aria-hidden="true" />
        <span class="mb-3 inline-flex w-fit items-center gap-2 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold backdrop-blur">
          <component :is="path.icon" class="size-3.5" />{{ $t(`client.home.paths.${path.key}.tag`) }}
        </span>
        <h3 class="text-2xl font-extrabold tracking-tight md:text-3xl">{{ $t(`client.home.paths.${path.key}.title`) }}</h3>
        <p class="mt-2 max-w-sm text-white/80">{{ $t(`client.home.paths.${path.key}.text`) }}</p>
        <span class="mt-5 inline-flex h-11 w-fit items-center gap-2 rounded-full bg-white px-5 text-sm font-semibold text-foreground">
          {{ $t(`client.home.paths.${path.key}.cta`) }}
          <ArrowRight class="size-4 transition-transform duration-300 group-hover:translate-x-1" />
        </span>
      </RouterLink>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { ArrowRight, Scissors, ShoppingBasket } from "lucide-vue-next";
import SectionHeading from "@/components/shop/SectionHeading.vue";
import ShopImage from "@/components/shop/ShopImage.vue";
import { SHOP_PHOTOS } from "@/config/shopImagery";

const paths = [
  { key: "shop", to: { name: "products" }, photo: SHOP_PHOTOS.shop, icon: ShoppingBasket },
  { key: "care", to: { name: "spa" }, photo: SHOP_PHOTOS.spa, icon: Scissors },
] as const;
</script>
