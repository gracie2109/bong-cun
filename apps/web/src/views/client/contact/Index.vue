<template>
  <div class="shop-container pb-16 pt-8 md:pt-14">
    <header class="max-w-2xl">
      <p class="shop-eyebrow">{{ $t("client.home.visit.eyebrow") }}</p>
      <h1 class="shop-display mt-2 text-[34px] leading-[1.1] md:text-5xl">{{ $t("client.contact.title") }}</h1>
      <p class="mt-4 text-lg text-muted-foreground">{{ $t("client.contact.subtitle") }}</p>
    </header>
    <div class="mt-10 grid gap-6 lg:grid-cols-[400px_1fr]">
      <div class="flex flex-col gap-6 rounded-3xl border bg-white p-6 md:p-8">
        <StoreContactList />
        <div class="mt-auto flex flex-col gap-3 sm:flex-row lg:flex-col">
          <Button as-child class="h-12 rounded-full px-6 text-base">
            <a :href="`tel:${STORE_INFO.phone}`"><Phone class="mr-2 size-4" />{{ $t("client.contact.call") }}</a>
          </Button>
          <Button as-child variant="outline" class="h-12 rounded-full px-6 text-base">
            <a :href="directionsUrl" target="_blank" rel="noopener"><Navigation class="mr-2 size-4" />{{ $t("client.home.visit.directions") }}</a>
          </Button>
        </div>
      </div>
      <div class="h-[360px] overflow-hidden rounded-3xl border bg-muted md:h-[460px]">
        <iframe
          :src="STORE_INFO.mapEmbedUrl"
          :title="$t('client.contact.map')"
          class="h-full w-full"
          loading="lazy"
          referrerpolicy="no-referrer-when-downgrade"
        ></iframe>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Navigation, Phone } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { STORE_INFO } from "@/config/storeInfo";
import StoreContactList from "@/views/client/layout/StoreContactList.vue";

const directionsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(STORE_INFO.address)}`;
</script>
