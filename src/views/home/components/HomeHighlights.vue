<template>
  <section class="shop-container" :aria-label="$t('client.home.highlights.label')">
    <ul class="grid grid-cols-1 gap-x-8 gap-y-5 border-y py-6 sm:grid-cols-2 lg:grid-cols-4 lg:py-7">
      <li v-for="item in SHOP_HIGHLIGHTS" :key="item.key" class="flex items-start gap-3.5">
        <component :is="item.icon" class="mt-0.5 size-6 shrink-0 text-primary" :stroke-width="1.6" aria-hidden="true" />
        <span class="min-w-0">
          <span class="block font-semibold">{{ $t(`client.home.highlights.${item.key}`) }}</span>
          <span class="mt-0.5 block text-sm text-muted-foreground">
            {{ $t(`client.home.highlights.${item.key}Text`, { hours: STORE_INFO.hours }) }}
          </span>
        </span>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { SHOP_HIGHLIGHTS } from "@/config/shopHighlights";
import { STORE_INFO } from "@/config/storeInfo";
</script>
