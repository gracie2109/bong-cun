<template>
  <section class="mt-16 bg-sage-soft py-14 md:mt-24 md:py-20" aria-labelledby="home-spa">
    <div class="shop-container">
      <div class="grid items-center gap-10 lg:grid-cols-12 lg:gap-14">
        <ShopImage
          :src="SHOP_PHOTOS.spa.src"
          :alt="$t(SHOP_PHOTOS.spa.alt)"
          :width="900"
          sizes="(min-width: 1024px) 45vw, 100vw"
          class="aspect-[4/3] rounded-[28px] lg:col-span-6 lg:aspect-[5/4]"
        />
        <div class="lg:col-span-6">
          <p class="shop-eyebrow !text-sage">{{ $t("client.home.spa.eyebrow") }}</p>
          <h2 id="home-spa" class="shop-display mt-2 text-3xl md:text-[40px] md:leading-tight">{{ $t("client.home.spa.title") }}</h2>
          <p class="mt-4 max-w-xl text-lg text-muted-foreground">{{ $t("client.home.spa.text") }}</p>
          <!-- Client only: the price list needs the branch first, which the server render cannot wait for. -->
          <ClientOnly>
            <template v-if="species && services.length > 0">
              <p class="mt-7 text-sm font-semibold text-sage">{{ $t("client.home.spa.priceFor", { species: species.name }) }}</p>
              <SpaServiceList class="mt-3" :services="services" :species="species" />
            </template>
            <template #fallback><div class="shop-skeleton mt-7 h-48 rounded-2xl" aria-hidden="true" /></template>
          </ClientOnly>
          <div class="mt-8 flex flex-col gap-3 sm:flex-row">
            <Button as-child class="h-12 rounded-full bg-sage px-6 text-base font-semibold hover:bg-sage/90">
              <RouterLink :to="{ path: '/spa/book' }"><CalendarHeart class="mr-2 size-5" />{{ $t("client.home.spa.book") }}</RouterLink>
            </Button>
            <Button as-child variant="outline" class="h-12 rounded-full border-sage/30 bg-transparent px-6 text-base font-semibold hover:bg-white">
              <RouterLink :to="{ name: 'spa' }">{{ $t("client.home.spa.prices") }}</RouterLink>
            </Button>
          </div>
        </div>
      </div>
      <BookingHowTo class="mt-14 border-t border-sage/15 pt-10" />
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { CalendarHeart } from "lucide-vue-next";
import ShopImage from "@/components/shop/ShopImage.vue";
import BookingHowTo from "@/components/shop/spa/BookingHowTo.vue";
import { Button } from "@/components/ui/button";
import { useSpaCatalog } from "@/features/shop/spa/composables/useSpaCatalog";
import { SHOP_PHOTOS } from "@/config/shopImagery";
import SpaServiceList from "./SpaServiceList.vue";

const HOME_SERVICES = 4;
const catalog = useSpaCatalog();
const species = computed(() => catalog.species.value);
const services = computed(() => catalog.services.value.slice(0, HOME_SERVICES));
</script>
