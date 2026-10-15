<template>
  <section class="mt-16 bg-sage-soft py-16 md:mt-24 md:py-24">
    <div class="shop-container">
      <div class="grid gap-10 lg:grid-cols-[1fr_1.4fr] lg:gap-16">
        <div class="lg:sticky lg:top-28 lg:self-start">
          <p class="shop-eyebrow !text-sage">{{ $t("client.home.spa.eyebrow") }}</p>
          <h2 class="shop-display mt-2 text-3xl md:text-[40px] md:leading-tight">{{ $t("client.home.spa.title") }}</h2>
          <p class="mt-4 text-lg text-muted-foreground">{{ $t("client.home.spa.text") }}</p>
          <div class="mt-8 flex flex-col gap-3 sm:flex-row">
            <Button as-child class="h-12 rounded-full bg-sage px-6 text-base hover:bg-sage/90">
              <RouterLink :to="{ path: '/spa/book' }"><CalendarHeart class="mr-2 size-5" />{{ $t("client.home.spa.book") }}</RouterLink>
            </Button>
            <Button as-child variant="outline" class="h-12 rounded-full border-sage/30 bg-transparent px-6 text-base hover:bg-white">
              <RouterLink :to="{ name: 'spa' }">{{ $t("client.home.spa.prices") }}</RouterLink>
            </Button>
          </div>
        </div>

        <div class="space-y-10">
          <!-- Client only: the combos need the branch first, which the server render cannot wait for. -->
          <ClientOnly>
            <ul v-if="combos.length > 0" class="grid gap-4 sm:grid-cols-2">
              <li v-for="(combo, index) in combos" :key="combo.id" class="shop-reveal" :style="{ '--i': index }">
                <ComboCard :combo="combo" />
              </li>
            </ul>
          </ClientOnly>
          <BookingHowTo />
        </div>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { CalendarHeart } from "lucide-vue-next";
import BookingHowTo from "@/components/shop/spa/BookingHowTo.vue";
import ComboCard from "@/components/shop/spa/ComboCard.vue";
import { Button } from "@/components/ui/button";
import { useSpaCatalog } from "@/composables/spa/useSpaCatalog";

const HOME_COMBOS = 4;
const catalog = useSpaCatalog();
const combos = computed(() => catalog.combos.value.slice(0, HOME_COMBOS));
</script>
