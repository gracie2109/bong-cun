<template>
  <section class="shop-container pt-16 md:pt-24">
    <div class="grid overflow-hidden rounded-[28px] bg-white ring-1 ring-border/70 md:grid-cols-2">
      <ShopImage
        :src="SHOP_PHOTOS.visit.src"
        :alt="$t(SHOP_PHOTOS.visit.alt)"
        :width="760"
        sizes="(min-width: 768px) 50vw, 100vw"
        class="aspect-[4/3] md:aspect-auto md:min-h-[380px]"
      />
      <div class="flex flex-col justify-center p-6 md:p-10 lg:p-12">
        <p class="shop-eyebrow">{{ $t("client.home.visit.eyebrow") }}</p>
        <h2 class="shop-display mt-2 text-2xl md:text-[32px] md:leading-tight">{{ $t("client.home.visit.title") }}</h2>
        <dl class="mt-6 space-y-4">
          <div v-for="row in rows" :key="row.label" class="flex gap-4">
            <dt class="grid size-10 shrink-0 place-content-center rounded-full bg-brand-soft text-primary">
              <component :is="row.icon" class="size-[18px]" /><span class="sr-only">{{ row.label }}</span>
            </dt>
            <dd class="pt-2 text-[15px]">
              <a v-if="row.href" :href="row.href" class="font-semibold hover:text-primary">{{ row.value }}</a>
              <span v-else>{{ row.value }}</span>
            </dd>
          </div>
        </dl>
        <div class="mt-8 flex flex-wrap gap-3">
          <Button as-child class="h-11 rounded-full px-5">
            <a :href="directionsUrl" target="_blank" rel="noopener"><Navigation class="mr-2 size-4" />{{ $t("client.home.visit.directions") }}</a>
          </Button>
          <Button as-child variant="outline" class="h-11 rounded-full px-5">
            <RouterLink :to="{ name: 'contact' }">{{ $t("client.nav.contact") }}</RouterLink>
          </Button>
        </div>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Clock, MapPin, Navigation, Phone } from "lucide-vue-next";
import ShopImage from "@/components/shop/ShopImage.vue";
import { Button } from "@/components/ui/button";
import { SHOP_PHOTOS } from "@/config/shopImagery";
import { STORE_INFO } from "@/config/storeInfo";

const { t } = useI18n();
const directionsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(STORE_INFO.address)}`;

const rows = computed(() => [
  { label: t("client.home.visit.address"), value: STORE_INFO.address, icon: MapPin, href: "" },
  { label: t("client.footer.hours"), value: STORE_INFO.hours, icon: Clock, href: "" },
  { label: t("client.footer.hotline"), value: STORE_INFO.phone, icon: Phone, href: `tel:${STORE_INFO.phone}` },
]);
</script>
