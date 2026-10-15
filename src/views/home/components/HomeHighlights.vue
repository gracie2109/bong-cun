<template>
  <section class="border-y bg-white" :aria-label="$t('client.home.highlights.label')">
    <ul class="shop-container grid grid-cols-2 lg:grid-cols-4">
      <li
        v-for="(item, index) in SHOP_HIGHLIGHTS"
        :key="item.key"
        class="flex items-start gap-3 py-5 sm:items-center sm:gap-4 sm:py-6 lg:px-6 lg:first:pl-0"
        :class="{ 'border-t lg:border-t-0': index > 1, 'lg:border-l': index > 0, 'pr-3': index % 2 === 0 }"
      >
        <span class="grid size-11 shrink-0 place-content-center rounded-full bg-brand-soft text-primary">
          <component :is="item.icon" class="size-5" :stroke-width="1.8" />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-semibold sm:text-[15px]">{{ $t(`client.home.highlights.${item.key}`) }}</span>
          <span class="mt-0.5 block text-xs text-muted-foreground sm:text-sm">
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
