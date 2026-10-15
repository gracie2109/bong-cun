<template>
  <div class="bg-foreground text-[13px] text-white/80">
    <div class="shop-container flex h-9 items-center justify-between gap-4">
      <p class="flex min-w-0 items-center gap-2 truncate">
        <Clock class="size-3.5 shrink-0 text-brand" />
        <span class="truncate">{{ $t("client.header.openHours", { hours: STORE_INFO.hours }) }}</span>
        <span class="hidden text-white/30 md:inline">·</span>
        <span class="hidden truncate md:inline">{{ STORE_INFO.address }}</span>
      </p>
      <a :href="`tel:${STORE_INFO.phone}`" class="inline-flex shrink-0 items-center gap-1.5 font-semibold text-white hover:text-brand">
        <Phone class="size-3.5" />{{ STORE_INFO.phone }}
      </a>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Clock, Phone } from "lucide-vue-next";
import { STORE_INFO } from "@/config/storeInfo";
</script>
